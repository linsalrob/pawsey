# Cited retrieval (RAG) on Setonix

This adds a cited retrieval service to either runtime: llama.cpp or Ollama on one
GCD. It retrieves passages from a local corpus of openly licensed articles and
asks the chat model to answer **only** from them, citing each passage by number.
Every reply carries the PMCID, DOI and section of each passage, so a reader can
check each citation.

The retrieval side is the same whichever runtime serves the chat model. It needs
only an OpenAI-compatible `/v1/chat/completions` URL. A llama.cpp server running
the embedding model shares the GCD with the chat model.

## Pieces

| file | does |
|---|---|
| `corpus.py` | `select` chooses CC BY / CC0 articles from Europe PMC by query, `fetch` downloads JATS full text (NCBI PMC), `chunk` splits it into ~220-word passages with section paths |
| `corpus/<name>.json` | the selection queries; `corpus/<name>.manifest.tsv` is the resulting article list (the reproducible record) |
| `fetch_corpus.slurm` | runs `fetch` and `chunk` on the copy partition |
| `rag.py` | `index` (embed passages, SQLite FTS5 + numpy vectors), `search`, `answer`, `serve` (HTTP) |
| `eval.py` | scores retrieval and cited answers against a question set with gold passages |
| `after_ready.sh` | hook for either `serve.slurm`: starts the embedding server, builds the index if needed, then serves or evaluates |

Python is `cray-python` (3.12, numpy). Nothing is pip-installed.

## Quick start

From the repository root:

```bash
export LLM_ROOT=/scratch/$PAWSEY_PROJECT/$USER/llm
# once: embedding model (640 MB) and corpus (~300 articles)
LLM_FETCH=embed sbatch --account=$PAWSEY_PROJECT --export=ALL llm/fetch_model.slurm
sbatch --account=$PAWSEY_PROJECT --export=ALL llm/rag/fetch_corpus.slurm

# serve: builds the index on first use, then serves until the job ends
LLM_AFTER_READY=llm/rag/after_ready.sh LLM_CTX=8192 \
    sbatch --account=${PAWSEY_PROJECT}-gpu --export=ALL llm/llama.cpp/serve.slurm
```

To use Ollama for the answers, submit `llm/ollama/serve.slurm` instead. Nothing
else changes.

The job log prints the tunnel command for the RAG port, which the job picks
from the free ports on its node. The API key is in
`$LLM_ROOT/llama-server.key`, the same key the chat server uses.

```bash
KEY=$(cat $LLM_ROOT/llama-server.key)
curl -s http://127.0.0.1:PORT/answer -H "Authorization: Bearer $KEY" \
    -d '{"question": "How does CheckV estimate genome completeness?", "k": 8}' | jq .answer,.cited
curl -s http://127.0.0.1:PORT/search -H "Authorization: Bearer $KEY" -d '{"query": "...", "k": 5}'
```

`/answer` returns:
- `answer`;
- `cited`, the passage IDs the answer cites;
- `passages`, the full text, PMCID, DOI and section of each retrieved passage;
- `abstained`, true when the model said the sources do not answer;
- `invalid_citations`, numbers outside the list;
- `uncited_sentences`.

## Evaluate

```bash
LLM_AFTER_READY=llm/rag/after_ready.sh LLM_CTX=8192 RAG_MODE=eval \
RAG_QUESTIONS=/path/to/questions.jsonl \
    sbatch --account=${PAWSEY_PROJECT}-gpu --export=ALL llm/llama.cpp/serve.slurm
```

The question format is in `eval.py`. Keep real evaluation sets out of this
public repository. The automatic metrics are:
- retrieval hit@k for dense, BM25 and fused ranking;
- whether the answer cites a gold passage;
- abstention on unanswerable questions;
- malformed citations.

Whether a cited passage actually supports its sentence needs a separate grader.
The results file keeps everything such a grader needs.

Gold passages say which source *should* be enough, not which is the only one.
In a corpus of reviews several articles often support the same answer, so a
correct answer citing a different article scores as a miss. Read the misses
before treating the number as an error rate.

## Design choices

- **Openly licensed text only.** `select` keeps only articles whose Europe PMC
  licence is CC BY or CC0, so passages can be stored and quoted with
  attribution. The text itself stays on `/scratch`, not in Git.
- **Embedding model:** Qwen3-Embedding-0.6B Q8_0 (Apache-2.0), pinned in
  `versions.env`.
  - It is served by the llama.cpp build already used for chat, with last-token
    pooling, so no new runtime is needed.
  - Queries carry Qwen's recommended `Instruct: ...\nQuery:` prefix. Passages
    are embedded as title, section and text.
- **At most three passages per article.** Long reviews otherwise fill every
  slot, leaving the answer with one source to cite.
- **Hybrid retrieval.** BM25 catches exact names: genes, tools, organisms.
  Embeddings catch paraphrase. Reciprocal rank fusion (k = 60) needs no score
  calibration.
- **Answers are greedy and non-thinking by default.** `--think` (or
  `RAG_EVAL_ARGS=--think`) lets Qwen3 reason first, which is slower.
- **Context:** eight passages plus the answer need ~6k tokens, so submit with
  `LLM_CTX=8192`.
