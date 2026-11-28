#!/usr/bin/env python3
"""Summarise bench.py results from one or more runs as a Markdown table.

    python3 summarise.py runs/llamacpp-<job>/bench.jsonl runs/ollama-<job>/bench.jsonl

Reports, per run: median generation speed over replies of >= 60 tokens, prompt
processing speed on the ~3.4k-token long-context prompt, the long-context
answer, stop-token leaks, and how many replies match the other run exactly
(greedy decoding: identical prefixes indicate the same template and weights;
later divergence is normal floating-point drift between builds).
"""
import json
import statistics
import sys


def load(path):
    with open(path) as fh:
        return {r["id"]: r for r in (json.loads(line) for line in fh if line.strip())}


runs = [(p, load(p)) for p in sys.argv[1:]]
print("| run | runtime | median tg tok/s | long-context pp tok/s | long-context answer (ref) "
      "| thinking reply has reasoning | stop leaks | identical replies |")
print("|---|---|---:|---:|---|---|---|---:|")
for i, (path, rs) in enumerate(runs):
    tg = statistics.median(r["tg_tok_s"] for r in rs.values() if r["gen_tokens"] >= 60)
    lc = rs.get("long-1", {})
    think = [r for r in rs.values() if r["thinking"]]
    leaks = sum(1 for r in rs.values() if r["stop_leak"])
    other = runs[1 - i][1] if len(runs) == 2 else {}
    same = sum(1 for k, r in rs.items() if k in other and other[k]["content"] == r["content"])
    print("| %s | %s | %.1f | %.0f | %s (%s) | %s | %d | %s |" % (
        path.split("/")[-2], next(iter(rs.values()))["runtime"], tg, lc.get("pp_tok_s") or 0,
        lc.get("content", "").strip(), lc.get("reference", ""),
        all(r["reasoning"] for r in think) if think else "n/a", leaks,
        "%d/%d" % (same, len(rs)) if other else "-"))
