#!/usr/bin/env python3
"""Build a small, openly licensed literature corpus for retrieval.

  corpus.py select  QUERIES.json MANIFEST.tsv   choose articles (Europe PMC search)
  corpus.py fetch   MANIFEST.tsv XML_DIR        download JATS full text (NCBI PMC), record SHA256
  corpus.py chunk   MANIFEST.tsv XML_DIR OUT.jsonl  split into citable passages

Only articles whose Europe PMC licence is CC BY or CC0 are selected, so the text
may be stored and quoted with attribution. The manifest (PMCID, DOI, year,
licence, title) is the reproducible record of the corpus. Re-running `select`
later can return a different set, because citation counts change. To rebuild
the same corpus, run `fetch` and `chunk` on a saved manifest.

Standard library only.
"""
import argparse
import csv
import hashlib
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

EPMC = "https://www.ebi.ac.uk/europepmc/webservices/rest"
OPEN_LICENCES = {"cc by", "cc0"}
FIELDS = ["pmcid", "doi", "year", "license", "cited_by", "query", "title"]
UA = {"User-Agent": "setonix-llm-rag/0.1 (corpus builder)"}


def _get(url, tries=5):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
                return r.read()
        except Exception as e:  # network hiccups: back off and retry
            if i == tries - 1:
                raise
            print(f"retry {i + 1} after {e}", file=sys.stderr)
            time.sleep(5 * (i + 1))


def select(args):
    spec = json.loads(Path(args.queries).read_text())
    rows, seen = [], set()
    for q in spec["queries"]:
        want, cursor, got = q["n"], "*", 0
        query = f'({q["query"]}) AND OPEN_ACCESS:y AND HAS_FT:y AND IN_EPMC:y ' \
                f'AND (LICENSE:"cc by" OR LICENSE:"cc0") {spec.get("filter", "")}'
        while got < want:
            params = {"query": query, "format": "json", "pageSize": 100,
                      "sort": spec.get("sort", "CITED desc"), "cursorMark": cursor,
                      "resultType": "core"}
            d = json.loads(_get(f"{EPMC}/search?{urllib.parse.urlencode(params)}"))
            res = d["resultList"]["result"]
            if not res:
                break
            for r in res:
                lic = (r.get("license") or "").lower()
                pmcid = r.get("pmcid")
                if not pmcid or pmcid in seen or lic not in OPEN_LICENCES:
                    continue
                seen.add(pmcid)
                rows.append({"pmcid": pmcid, "doi": r.get("doi", ""), "year": r.get("pubYear", ""),
                             "license": lic, "cited_by": r.get("citedByCount", 0),
                             "query": q["name"],
                             "title": re.sub(r"<[^>]+>|\s+", " ", r.get("title", "")).strip()})
                got += 1
                if got >= want:
                    break
            cursor = d.get("nextCursorMark", cursor)
        print(f"{q['name']}: {got} articles", file=sys.stderr)
    with open(args.manifest, "w", newline="") as f:
        w = csv.DictWriter(f, FIELDS, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {len(rows)} rows to {args.manifest}")


def read_manifest(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


EFETCH = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"


def _pmcid_of(article):
    for a in article.iter("article-id"):
        if a.get("pub-id-type") in ("pmc", "pmcid"):
            v = (a.text or "").strip()
            return v if v.startswith("PMC") else f"PMC{v}"
    return None


def fetch(args):
    """NCBI efetch in batches (fast); Europe PMC one at a time for anything missed."""
    out = Path(args.xml_dir)
    out.mkdir(parents=True, exist_ok=True)
    want = [r["pmcid"] for r in read_manifest(args.manifest)]
    todo = [p for p in want if not (out / f"{p}.xml").exists()]
    for i in range(0, len(todo), 50):
        ids = ",".join(p[3:] for p in todo[i:i + 50])
        root = ET.fromstring(_get(f"{EFETCH}?db=pmc&retmode=xml&tool=setonix-llm-rag&id={ids}"))
        for art in root.findall("article"):
            pmcid = _pmcid_of(art)
            if pmcid in todo and art.find("body") is not None:
                tmp = out / f"{pmcid}.part"
                tmp.write_bytes(ET.tostring(art, encoding="utf-8"))
                tmp.rename(out / f"{pmcid}.xml")
        print(f"efetch {min(i + 50, len(todo))}/{len(todo)}", file=sys.stderr)
        time.sleep(0.5)  # NCBI allows 3 requests/s without an API key
    failed = []
    for p in want:
        dest = out / f"{p}.xml"
        if dest.exists():
            continue
        try:  # not in PMC's full-text set: try Europe PMC
            data = _get(f"{EPMC}/{p}/fullTextXML")
            if b"<body" not in data:
                raise ValueError("no body")
            dest.with_suffix(".part").write_bytes(data)
            dest.with_suffix(".part").rename(dest)
        except Exception as e:
            failed.append(p)
            print(f"FAILED {p}: {e}", file=sys.stderr)
    sums = [f"{hashlib.sha256((out / f'{p}.xml').read_bytes()).hexdigest()}  {p}.xml\n"
            for p in want if (out / f"{p}.xml").exists()]
    (out / "SHA256SUMS").write_text("".join(sums))
    print(f"{len(sums)} articles in {out}; {len(failed)} without full text {failed}")


# ---- chunking -------------------------------------------------------------
SKIP_SECTIONS = re.compile(
    r"^(references?|acknowledg|funding|author.? contribution|conflicts? of interest|"
    r"competing interest|declaration|data availability|ethics|abbreviations|"
    r"supplementary|publisher.?s note|consent|reporting summary|lead contact|"
    r"(materials?|resource|code|software) availability|key resources table)", re.I)


def _text(el):
    return re.sub(r"\s+", " ", "".join(el.itertext())).strip()


def _paragraphs(sec, path):
    """Yield (section_path, paragraph_text) in document order, recursing into sub-sections."""
    title = sec.find("title")
    here = path + [_text(title)] if title is not None and _text(title) else path
    if here and SKIP_SECTIONS.match(here[-1]):
        return
    for child in sec:
        tag = child.tag
        if tag == "p":
            # drop nested tables/figures that occasionally sit inside <p>
            for junk in child.findall(".//table-wrap") + child.findall(".//fig"):
                junk.clear()
            t = _text(child)
            if len(t.split()) >= 8:
                yield " > ".join(here) or "Body", t
        elif tag == "sec":
            yield from _paragraphs(child, here)


def _split_long(text, limit):
    words = text.split()
    if len(words) <= limit:
        return [text]
    sents = re.split(r"(?<=[.!?])\s+(?=[A-Z(\[])", text)
    out, cur = [], []
    for s in sents:
        if cur and len(" ".join(cur + [s]).split()) > limit:
            out.append(" ".join(cur))
            cur = []
        cur.append(s)
    if cur:
        out.append(" ".join(cur))
    return out


def chunk_article(xml_bytes, meta, target=220, limit=380):
    root = ET.fromstring(xml_bytes)
    front = root.find(".//article-meta")
    title = _text(front.find(".//article-title")) if front is not None and \
        front.find(".//article-title") is not None else meta["title"]
    units = []
    for ab in root.findall(".//article-meta/abstract"):
        if ab.get("abstract-type") in ("graphical", "teaser"):
            continue
        for sec_path, t in _paragraphs(ab, ["Abstract"]):
            units.append((sec_path, t))
    body = root.find(".//body")
    if body is not None:
        units.extend(_paragraphs(body, []))
    # Merge short consecutive paragraphs within a section; split long ones.
    passages, cur_sec, cur = [], None, []
    def flush():
        if cur:
            passages.append((cur_sec, " ".join(cur)))
    for sec_path, t in units:
        for piece in _split_long(t, limit):
            n = len(piece.split())
            if sec_path != cur_sec or (cur and len(" ".join(cur).split()) + n > target):
                flush()
                cur_sec, cur = sec_path, []
            cur.append(piece)
    flush()
    for k, (sec_path, t) in enumerate(passages):
        yield {"id": f"{meta['pmcid']}:{k:03d}", "pmcid": meta["pmcid"], "doi": meta["doi"],
               "year": meta["year"], "license": meta["license"], "title": title,
               "section": sec_path, "text": t}


def chunk(args):
    xml_dir, n_art, n_pass, empty = Path(args.xml_dir), 0, 0, []
    with open(args.out, "w") as f:
        for r in read_manifest(args.manifest):
            p = xml_dir / f"{r['pmcid']}.xml"
            if not p.exists():
                empty.append(r["pmcid"])
                continue
            ps = list(chunk_article(p.read_bytes(), r))
            if len(ps) < 3:  # abstract-only or unparsable full text
                empty.append(r["pmcid"])
            n_art += 1
            for x in ps:
                f.write(json.dumps(x, ensure_ascii=False) + "\n")
                n_pass += 1
    print(f"{n_pass} passages from {n_art} articles -> {args.out}; "
          f"{len(empty)} missing or under 3 passages: {empty}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("select"); s.add_argument("queries"); s.add_argument("manifest")
    s = sub.add_parser("fetch"); s.add_argument("manifest"); s.add_argument("xml_dir")
    s = sub.add_parser("chunk"); s.add_argument("manifest"); s.add_argument("xml_dir"); s.add_argument("out")
    a = ap.parse_args()
    sys.exit({"select": select, "fetch": fetch, "chunk": chunk}[a.cmd](a) or 0)


if __name__ == "__main__":
    main()
