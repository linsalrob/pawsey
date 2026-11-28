#!/usr/bin/env python3
"""Score retrieval and cited answers against a question set with gold passages.

  eval.py --root DIR --embed-url URL --chat-url URL --chat-model M \
          --questions questions.jsonl --out results.jsonl [--think]

Each question line is
  {"id": "q01", "question": "...", "answerable": true,
   "gold": ["PMC1234567:012", ...]}
Gold entries are passage IDs, or a bare PMCID when any passage of that article
counts. Unanswerable questions (answerable false, gold empty) test whether the
model says that the sources do not answer them.

Automatic metrics:
- retrieval hit@k and reciprocal rank of the first gold passage, for dense,
  BM25 and fused ranking;
- abstention;
- whether the answer cites a gold passage;
- citation numbers outside the passage list;
- sentences without a citation.

Whether each cited passage actually supports its sentence is not scored here.
That needs a grader other than the model that wrote the answer, so the
results file keeps the full answer and passages for external grading.
"""
import argparse
import json
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rag  # noqa: E402


def is_gold(pid, gold):
    return pid in gold or pid.split(":")[0] in gold


def first_hit(ids, gold):
    return next((i + 1 for i, x in enumerate(ids) if is_gold(x, gold)), None)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for a in ("--root", "--embed-url", "--chat-url", "--chat-model", "--questions", "--out"):
        ap.add_argument(a, required=True)
    ap.add_argument("--embed-key-file")
    ap.add_argument("--chat-key-file")
    ap.add_argument("--think", action="store_true")
    ap.add_argument("-k", type=int, default=8)
    ap.add_argument("--label", default="")
    a = ap.parse_args()
    idx = rag.Index(a.root, rag.Embedder(a.embed_url, rag._key(a.embed_key_file)))
    ans = rag.Answerer(idx, a.chat_url, a.chat_model, rag._key(a.chat_key_file), a.think)
    qs = [json.loads(l) for l in open(a.questions) if l.strip()]
    rows = []
    with open(a.out, "w") as f:
        for q in qs:
            gold = set(q.get("gold", []))
            dense, sparse = idx.rankings(q["question"], 50)
            r = ans(q["question"], a.k)
            hybrid = [p["id"] for p in r["passages"]]
            rec = {"id": q["id"], "label": a.label, "answerable": q.get("answerable", True),
                   "rank_dense": first_hit(idx.ids(dense), gold) if gold else None,
                   "rank_bm25": first_hit(idx.ids(sparse), gold) if gold else None,
                   "rank_hybrid": first_hit(hybrid, gold) if gold else None,
                   "cites_gold": any(is_gold(c, gold) for c in r["cited"]) if gold else None,
                   **{k: r[k] for k in ("answer", "reasoning", "abstained", "cited", "invalid_citations",
                                        "uncited_sentences", "usage", "search_s", "total_s")},
                   "passages": [{k: p[k] for k in ("id", "pmcid", "section", "text")} for p in r["passages"]],
                   "question": q["question"], "gold": sorted(gold)}
            rows.append(rec)
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            f.flush()
            print(f"{q['id']}: hybrid_rank={rec['rank_hybrid']} cites_gold={rec['cites_gold']} "
                  f"abstained={rec['abstained']} {rec['total_s']}s", file=sys.stderr)
    print(summarise(rows, a.k))


def summarise(rows, k=8):
    ans = [r for r in rows if r["answerable"]]
    un = [r for r in rows if not r["answerable"]]
    def hit(key, kk):
        return sum(1 for r in ans if r[key] and r[key] <= kk) / max(len(ans), 1)
    def mrr(key):
        return statistics.mean([1 / r[key] if r[key] else 0 for r in ans]) if ans else 0
    lines = [f"answerable={len(ans)} unanswerable={len(un)}",
             "| ranking | hit@1 | hit@5 | hit@%d | MRR@50 |" % k, "|---|---:|---:|---:|---:|"]
    for key in ("rank_dense", "rank_bm25", "rank_hybrid"):
        lines.append(f"| {key[5:]} | {hit(key, 1):.2f} | {hit(key, 5):.2f} | {hit(key, k):.2f} | {mrr(key):.2f} |")
    lines += [
        f"answerable: cites a gold passage {sum(bool(r['cites_gold']) for r in ans)}/{len(ans)}; "
        f"wrongly abstained {sum(r['abstained'] for r in ans)}/{len(ans)}",
        f"unanswerable: abstained {sum(r['abstained'] for r in un)}/{len(un)}",
        f"invalid citation numbers in {sum(bool(r['invalid_citations']) for r in rows)} answers; "
        f"uncited sentences {sum(len(r['uncited_sentences']) for r in rows)} in total",
        f"median answer time {statistics.median([r['total_s'] for r in rows]):.1f}s"]
    return "\n".join(lines)


if __name__ == "__main__":
    main()
