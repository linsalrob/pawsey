#!/usr/bin/env python3
"""Matched-settings benchmark client for llama.cpp's llama-server and Ollama.

Sends the same prompts to either server using greedy decoding (temperature 0,
top_k 1, fixed seed), reasoning disabled unless a prompt asks for it, and the
same generation limits, then writes one JSON record per prompt with the reply,
token counts and the server's own prompt-processing and generation timings.

Standard library only (Python >= 3.8). Example:
    python3 bench.py --api llamacpp --url http://127.0.0.1:8080 \
        --model qwen3-32b --prompts prompts.jsonl --out results.jsonl
"""
import argparse
import json
import random
import sys
import time
import urllib.request

STOP_LEAKS = ("<|im_end|>", "<|im_start|>", "<|endoftext|>", "<think>", "</think>")


HEADERS = {"Content-Type": "application/json"}


def post(url, body, timeout=1800):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=HEADERS)
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        data = json.load(r)
    return data, time.monotonic() - t0


def long_context_prompt(n=150, seed=7):
    """Synthetic table with one known answer, ~3k tokens: tests prefill speed
    and that the whole context was actually read."""
    rng = random.Random(seed)
    genera = ["Bacteroides", "Prevotella", "Faecalibacterium", "Escherichia",
              "Bifidobacterium", "Akkermansia", "Roseburia", "Ruminococcus"]
    rows, best = [], None
    for i in range(1, n + 1):
        reads = rng.randint(100000, 900000)
        rows.append("Sample S%03d: reads=%d, dominant genus=%s" % (i, reads, rng.choice(genera)))
        if best is None or reads > best[1]:
            best = ("S%03d" % i, reads)
    prompt = ("Here are sequencing results:\n" + "\n".join(rows) +
              "\n\nWhich sample has the largest number of reads? Reply with only the sample ID.")
    return {"id": "long-1", "category": "long-context", "prompt": prompt,
            "reference": best[0], "max_tokens": 32}


def run_llamacpp(args, p, thinking, max_tokens):
    body = {"model": args.model,
            "messages": [{"role": "user", "content": p["prompt"]}],
            "temperature": 0, "top_k": 1, "seed": args.seed, "max_tokens": max_tokens,
            "cache_prompt": False,
            "chat_template_kwargs": {"enable_thinking": thinking}}
    d, wall = post(args.url.rstrip("/") + "/v1/chat/completions", body)
    msg, t = d["choices"][0]["message"], d.get("timings", {})
    return {"content": msg.get("content") or "", "reasoning": msg.get("reasoning_content") or "",
            "finish": d["choices"][0].get("finish_reason"), "wall_s": wall,
            "prompt_tokens": t.get("prompt_n"), "prompt_s": (t.get("prompt_ms") or 0) / 1e3,
            "gen_tokens": t.get("predicted_n"), "gen_s": (t.get("predicted_ms") or 0) / 1e3,
            "load_s": None}


def run_ollama(args, p, thinking, max_tokens):
    body = {"model": args.model, "stream": False, "think": thinking,
            "messages": [{"role": "user", "content": p["prompt"]}],
            "options": {"temperature": 0, "top_k": 1, "seed": args.seed,
                        "num_predict": max_tokens, "num_ctx": args.ctx,
                        "num_batch": 512}}
    if args.threads:
        body["options"]["num_thread"] = args.threads
    d, wall = post(args.url.rstrip("/") + "/api/chat", body)
    msg = d.get("message", {})
    return {"content": msg.get("content") or "", "reasoning": msg.get("thinking") or "",
            "finish": d.get("done_reason"), "wall_s": wall,
            "prompt_tokens": d.get("prompt_eval_count"), "prompt_s": d.get("prompt_eval_duration", 0) / 1e9,
            "gen_tokens": d.get("eval_count"), "gen_s": d.get("eval_duration", 0) / 1e9,
            "load_s": d.get("load_duration", 0) / 1e9}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--api", choices=["llamacpp", "ollama"], required=True)
    ap.add_argument("--url", required=True)
    ap.add_argument("--model", required=True)
    ap.add_argument("--api-key-file", help="file holding a bearer token (llama-server --api-key-file)")
    ap.add_argument("--prompts", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--max-tokens", type=int, default=512)
    ap.add_argument("--ctx", type=int, default=4096)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--threads", type=int, default=0,
                    help="Ollama only: send options.num_thread (0 = Ollama's default)")
    args = ap.parse_args()
    if args.api_key_file:
        with open(args.api_key_file) as fh:
            HEADERS["Authorization"] = "Bearer " + fh.read().strip()
    run = run_llamacpp if args.api == "llamacpp" else run_ollama

    with open(args.prompts) as fh:
        prompts = [json.loads(line) for line in fh if line.strip()]
    prompts.append(long_context_prompt())
    with open(args.out, "w") as out:
        for p in prompts:
            thinking = bool(p.get("thinking", False))
            r = run(args, p, thinking, p.get("max_tokens", args.max_tokens))
            text = r["content"] + r["reasoning"]
            r.update({"id": p["id"], "category": p["category"], "thinking": thinking,
                      "reference": p["reference"], "runtime": args.api,
                      "stop_leak": [s for s in STOP_LEAKS if s in r["content"]],
                      "pp_tok_s": r["prompt_tokens"] / r["prompt_s"] if r["prompt_s"] else None,
                      "tg_tok_s": r["gen_tokens"] / r["gen_s"] if r["gen_s"] else None})
            out.write(json.dumps(r) + "\n")
            out.flush()
            print("%-8s pp=%5s tok %7.1f tok/s  tg=%4s tok %6.1f tok/s  finish=%s think=%d chars leak=%s" % (
                p["id"], r["prompt_tokens"], r["pp_tok_s"] or 0, r["gen_tokens"], r["tg_tok_s"] or 0,
                r["finish"], len(r["reasoning"]), r["stop_leak"]), flush=True)
            if not text.strip():
                print("ERROR: empty reply for %s" % p["id"], file=sys.stderr)


if __name__ == "__main__":
    main()
