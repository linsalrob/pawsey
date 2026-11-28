#!/usr/bin/env python3
"""Cited retrieval over a passage corpus, independent of the chat runtime.

  rag.py index  --root DIR --embed-url URL         embed passages.jsonl, build the index
  rag.py search --root DIR --embed-url URL "query"
  rag.py answer --root DIR --embed-url URL --chat-url URL --chat-model M "question"
  rag.py serve  --root DIR --embed-url URL --chat-url URL --chat-model M --port P

Retrieval is hybrid. BM25 comes from SQLite FTS5 and cosine similarity from an
embedding model behind an OpenAI-compatible /v1/embeddings endpoint (llama.cpp
`llama-server --embedding`). The two rankings are fused with reciprocal rank
fusion. Answers come from any OpenAI-compatible /v1/chat/completions endpoint:
llama.cpp, Ollama, or anything else. The model may use only the numbered
passages and must cite them. Each reply returns those passages, with PMCID, DOI
and section, so every citation can be checked.

The service binds to loopback and, given --api-key-file, requires
`Authorization: Bearer <key>`. Needs Python >= 3.8 and numpy.
"""
import argparse
import json
import re
import sqlite3
import sys
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import numpy as np

QUERY_INSTRUCT = "Given a question about microbiology, retrieve passages from scientific articles that answer it"
SYSTEM_PROMPT = (
    "You answer questions about microbiology and microbiome research using ONLY the numbered "
    "passages provided. Cite the passage numbers that support each sentence in square brackets, "
    "for example [2] or [1][4]. Do not cite a passage for something it does not say. If the "
    "passages do not contain the answer, reply exactly: \"The provided sources do not answer this "
    "question.\" and then say briefly what they do cover. Do not add facts from outside the passages. "
    "Be concise.")
ABSTAIN = re.compile(r"provided sources do not answer", re.I)
CITE = re.compile(r"\[(\d+(?:\s*[,;–-]\s*\d+)*)\]")


def _post(url, body, key=None, timeout=600):
    h = {"Content-Type": "application/json"}
    if key:
        h["Authorization"] = f"Bearer {key}"
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=h)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def _key(path):
    return Path(path).read_text().strip() if path else None


class Embedder:
    def __init__(self, url, key=None, model="embed"):
        self.url, self.key, self.model = url.rstrip("/") + "/embeddings", key, model

    def __call__(self, texts):
        d = _post(self.url, {"input": texts, "model": self.model}, self.key)
        v = np.array([x["embedding"] for x in sorted(d["data"], key=lambda x: x["index"])],
                     dtype=np.float32)
        return v / np.linalg.norm(v, axis=1, keepdims=True)

    def query(self, q):
        return self([f"Instruct: {QUERY_INSTRUCT}\nQuery:{q}"])[0]


# ---- index -----------------------------------------------------------------
def build_index(root, embed, batch=32):
    root = Path(root)
    rows = [json.loads(l) for l in open(root / "passages.jsonl")]
    db = root / "index.sqlite"
    db.unlink(missing_ok=True)
    con = sqlite3.connect(db)
    con.execute("create table passages (n integer primary key, id text unique, pmcid text, doi text, "
                "year text, license text, title text, section text, text text)")
    con.execute("create virtual table fts using fts5(title, section, text, content='passages', "
                "content_rowid='n', tokenize='porter unicode61')")
    con.executemany("insert into passages values (?,?,?,?,?,?,?,?,?)",
                    [(i, r["id"], r["pmcid"], r["doi"], r["year"], r["license"], r["title"],
                      r["section"], r["text"]) for i, r in enumerate(rows)])
    con.execute("insert into fts(rowid, title, section, text) select n, title, section, text from passages")
    con.commit()
    t0, vecs = time.time(), []
    for i in range(0, len(rows), batch):
        vecs.append(embed([f"{r['title']}\n{r['section']}\n{r['text']}" for r in rows[i:i + batch]]))
        if (i // batch) % 50 == 0:
            print(f"embedded {i + len(vecs[-1])}/{len(rows)}", file=sys.stderr)
    V = np.vstack(vecs)
    np.save(root / "vectors.npy", V)
    meta = {"passages": len(rows), "dim": int(V.shape[1]), "embed_s": round(time.time() - t0, 1),
            "built": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
    (root / "index.json").write_text(json.dumps(meta, indent=1))
    print(json.dumps(meta))


class Index:
    def __init__(self, root, embed):
        root = Path(root)
        self.con = sqlite3.connect(root / "index.sqlite", check_same_thread=False)
        self.V = np.load(root / "vectors.npy")
        self.embed = embed

    def _bm25(self, q, n):
        terms = [t for t in re.findall(r"\w+", q.lower()) if len(t) > 2]
        if not terms:
            return []
        expr = " OR ".join(f'"{t}"' for t in terms)
        return [r[0] for r in self.con.execute(
            "select rowid from fts where fts match ? order by bm25(fts, 2.0, 1.0, 1.0) limit ?", (expr, n))]

    def rankings(self, q, pool=50):
        """Row numbers ranked by embedding similarity and by BM25."""
        return np.argsort(-(self.V @ self.embed.query(q)))[:pool].tolist(), self._bm25(q, pool)

    def ids(self, rows):
        return [self.con.execute("select id from passages where n = ?", (n,)).fetchone()[0] for n in rows]

    def search(self, q, k=8, pool=50, rrf=60, per_article=3):
        """Fuse the two rankings with RRF, keeping at most per_article passages
        per article so a few long articles cannot fill every slot."""
        dense, sparse = self.rankings(q, pool)
        score = {}
        for ranking in (dense, sparse):
            for rank, n in enumerate(ranking):
                score[n] = score.get(n, 0.0) + 1.0 / (rrf + rank + 1)
        cols = ["id", "pmcid", "doi", "year", "license", "title", "section", "text"]
        rows, seen = [], {}
        for n in sorted(score, key=score.get, reverse=True):
            r = self.con.execute(f"select {', '.join(cols)} from passages where n = ?", (n,)).fetchone()
            pmcid = r[1]
            if per_article and seen.get(pmcid, 0) >= per_article:
                continue
            seen[pmcid] = seen.get(pmcid, 0) + 1
            rows.append((n, r))
            if len(rows) >= k:
                break
        out = []
        for n, r in rows:
            out.append(dict(zip(cols, r),
                            score=round(score[n], 5),
                            dense_rank=dense.index(n) + 1 if n in dense else None,
                            bm25_rank=sparse.index(n) + 1 if n in sparse else None))
        return out


# ---- answer ----------------------------------------------------------------
def parse_citations(text, n_passages):
    cited, invalid = [], []
    for m in CITE.finditer(text):
        for part in re.split(r"\s*[,;]\s*", m.group(1)):
            rng = re.split(r"\s*[–-]\s*", part)
            nums = range(int(rng[0]), int(rng[-1]) + 1) if len(rng) == 2 else [int(rng[0])]
            for x in nums:
                (cited if 1 <= x <= n_passages else invalid).append(x)
    sentences = [s for s in re.split(r"(?<=[.!?])\s+", text.strip()) if len(s.split()) > 3]
    uncited = [s for s in sentences if not CITE.search(s) and not ABSTAIN.search(s)]
    return sorted(set(cited)), sorted(set(invalid)), uncited


class Answerer:
    def __init__(self, index, chat_url, chat_model, key=None, think=False, max_tokens=1024):
        self.index, self.url, self.model = index, chat_url.rstrip("/") + "/chat/completions", chat_model
        self.key, self.think, self.max_tokens = key, think, max_tokens

    def __call__(self, question, k=8):
        t0 = time.time()
        ps = self.index.search(question, k)
        t_search = time.time() - t0
        ctx = "\n\n".join(f"[{i}] ({p['pmcid']}; {p['title']}; {p['section']})\n{p['text']}"
                          for i, p in enumerate(ps, 1))
        body = {"model": self.model, "temperature": 0, "top_p": 1, "seed": 42,
                "max_tokens": self.max_tokens if not self.think else 6000,
                "messages": [{"role": "system", "content": SYSTEM_PROMPT},
                             {"role": "user", "content": f"Passages:\n\n{ctx}\n\nQuestion: {question}"}],
                # Qwen3 thinking switch: llama.cpp reads chat_template_kwargs, Ollama's
                # OpenAI endpoint reads reasoning_effort; each ignores the other.
                "chat_template_kwargs": {"enable_thinking": self.think}}
        if not self.think:
            body["reasoning_effort"] = "none"
        d = _post(self.url, body, self.key)
        msg = d["choices"][0]["message"]
        text = re.sub(r"<think>.*?</think>", "", msg.get("content") or "", flags=re.S).strip()
        cited, invalid, uncited = parse_citations(text, len(ps))
        return {"question": question, "answer": text,
                "reasoning": msg.get("reasoning_content") or msg.get("reasoning") or "",
                "abstained": bool(ABSTAIN.search(text)),
                "cited": [ps[i - 1]["id"] for i in cited], "invalid_citations": invalid,
                "uncited_sentences": uncited, "passages": ps, "usage": d.get("usage", {}),
                "search_s": round(t_search, 3), "total_s": round(time.time() - t0, 2)}


# ---- HTTP service ----------------------------------------------------------
def serve(answerer, host, port, key):
    class H(BaseHTTPRequestHandler):
        def _send(self, code, obj):
            b = json.dumps(obj, ensure_ascii=False).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)

        def _authorised(self):
            return not key or self.headers.get("Authorization") == f"Bearer {key}"

        def do_GET(self):
            if self.path == "/health":
                return self._send(200, {"status": "ok"})
            self._send(404, {"error": "not found"})

        def do_POST(self):
            if not self._authorised():
                return self._send(401, {"error": "missing or wrong API key"})
            try:
                req = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
                k = int(req.get("k", 8))
                if self.path == "/search":
                    return self._send(200, {"passages": answerer.index.search(req["query"], k)})
                if self.path == "/answer":
                    return self._send(200, answerer(req["question"], k))
                self._send(404, {"error": "use POST /search or POST /answer"})
            except Exception as e:
                self._send(400, {"error": str(e)})

        def log_message(self, fmt, *a):
            sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % a))

    print(f"RAG service on http://{host}:{port} (POST /search, POST /answer, GET /health)", flush=True)
    ThreadingHTTPServer((host, port), H).serve_forever()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["index", "search", "answer", "serve"])
    ap.add_argument("text", nargs="?")
    ap.add_argument("--root", required=True)
    ap.add_argument("--embed-url", required=True, help="OpenAI-compatible base, e.g. http://127.0.0.1:PORT/v1")
    ap.add_argument("--embed-key-file")
    ap.add_argument("--chat-url")
    ap.add_argument("--chat-model")
    ap.add_argument("--chat-key-file")
    ap.add_argument("--think", action="store_true", help="let Qwen3 reason before answering (slower)")
    ap.add_argument("-k", type=int, default=8)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int)
    ap.add_argument("--api-key-file", help="require this bearer key on the RAG service")
    a = ap.parse_args()
    embed = Embedder(a.embed_url, _key(a.embed_key_file))
    if a.cmd == "index":
        return build_index(a.root, embed)
    idx = Index(a.root, embed)
    if a.cmd == "search":
        for p in idx.search(a.text, a.k):
            print(f"{p['score']:.4f} d{p['dense_rank']} b{p['bm25_rank']} {p['id']} {p['section'][:40]} | {p['text'][:120]}")
        return
    ans = Answerer(idx, a.chat_url, a.chat_model, _key(a.chat_key_file), a.think)
    if a.cmd == "answer":
        r = ans(a.text, a.k)
        print(r["answer"])
        for i, p in enumerate(r["passages"], 1):
            print(f"[{i}] {p['id']} doi:{p['doi']} {p['section'][:60]}")
        return
    serve(ans, a.host, a.port, _key(a.api_key_file))


if __name__ == "__main__":
    main()
