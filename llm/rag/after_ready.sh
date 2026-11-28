#!/bin/bash
# Cited retrieval on the same GCD as a running chat server. Do not run this
# directly. Pass it as the after-ready hook of either runtime's launcher:
#
#   LLM_AFTER_READY=llm/rag/after_ready.sh RAG_MODE=serve LLM_CTX=8192 \
#       sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/llama.cpp/serve.slurm
#   (or llm/ollama/serve.slurm; the retrieval side is identical)
#
# The script:
# 1. starts the embedding model on llama.cpp (llama-server --embedding, ~1 GB VRAM);
# 2. builds the index from $RAG_ROOT/passages.jsonl, if missing or RAG_REBUILD=1;
# 3. then, by RAG_MODE:
#    - serve (default): runs the RAG HTTP service until the job ends;
#    - eval: scores RAG_QUESTIONS and writes the results to the run directory;
#    - index: stops after building the index.
set -euo pipefail
HERE=${LLM_DIR:-${SLURM_SUBMIT_DIR:-.}/llm}
# shellcheck source=../versions.env
source "$HERE/versions.env"
# shellcheck source=../lib.sh
source "$HERE/lib.sh"
: "${LLM_CHAT_URL:?Run via LLM_AFTER_READY in a serve.slurm launcher}"
module load "$LLAMA_ROCM_MODULE" cray-python

[[ -r $EMBED_GGUF ]] || { echo "Missing $EMBED_GGUF; run LLM_FETCH=embed llm/fetch_model.slurm" >&2; exit 1; }
[[ -s $RAG_ROOT/passages.jsonl ]] || { echo "Missing $RAG_ROOT/passages.jsonl; run llm/rag/fetch_corpus.slurm" >&2; exit 1; }
echo "embed=$EMBED_GGUF sha256=$EMBED_SHA256 ($EMBED_REPO@$EMBED_REVISION, $EMBED_LICENSE)"
echo "corpus=$RAG_ROOT ($(wc -l < "$RAG_ROOT/passages.jsonl") passages) chat=$LLM_RUNTIME:$LLM_CHAT_MODEL"

# Eight ~300-word passages plus the answer need about 6k tokens of context.
(( LLM_CTX >= 8192 )) || echo "WARNING: LLM_CTX=$LLM_CTX; submit with LLM_CTX=8192 or more for RAG" >&2

# Free ports for the embedding server and the RAG service. The chat server
# already holds one, and other jobs on this shared node hold others.
eport=$(llm_port) rport=$(llm_port $(( eport + 1 )))
keyfile=$LLM_ROOT/llama-server.key
if [[ ! -s $keyfile ]]; then (umask 077; head -c 24 /dev/urandom | base64 > "$keyfile"); fi

# --overlap lets this step share the GCD (and cores) with the chat server's step.
# Inputs are embedded whole, so the physical batch must hold the longest passage.
srun --overlap --ntasks=1 --gpus-per-task=1 "$LLAMA_PREFIX/bin/llama-server" \
    --model "$EMBED_GGUF" --embedding --pooling last --n-gpu-layers 999 \
    --ctx-size 16384 --parallel 4 --batch-size 8192 --ubatch-size 8192 \
    --threads "${LLM_THREADS:-$(llm_threads)}" --host 127.0.0.1 --port "$eport" \
    --api-key-file "$keyfile" > "$LLM_RUN_DIR/embed-server.log" 2>&1 &
epid=$!
trap 'llm_stop "$epid" "llama-server.*--embedding"' EXIT
llm_wait_ready "http://127.0.0.1:$eport/health" "$epid" 300

common=(--root "$RAG_ROOT" --embed-url "http://127.0.0.1:$eport/v1" --embed-key-file "$keyfile")
chat=(--chat-url "$LLM_CHAT_URL" --chat-model "$LLM_CHAT_MODEL")
[[ -n ${LLM_CHAT_KEY_FILE:-} ]] && chat+=(--chat-key-file "$LLM_CHAT_KEY_FILE")

if [[ ! -s $RAG_ROOT/vectors.npy || ${RAG_REBUILD:-0} == 1 ]]; then
    python3 "$HERE/rag/rag.py" index "${common[@]}"
fi
cat "$RAG_ROOT/index.json"

case ${RAG_MODE:-serve} in
index) ;;
eval)
    : "${RAG_QUESTIONS:?Set RAG_QUESTIONS=/path/to/questions.jsonl}"
    python3 "$HERE/rag/eval.py" "${common[@]}" "${chat[@]}" --questions "$RAG_QUESTIONS" \
        --label "$LLM_RUNTIME" --out "$LLM_RUN_DIR/rag-eval.jsonl" ${RAG_EVAL_ARGS:-} \
        | tee "$LLM_RUN_DIR/rag-eval.md"
    ;;
serve)
    llm_tunnel_hint "$rport"
    echo "RAG API key file: $keyfile (same key as llama-server)"
    python3 "$HERE/rag/rag.py" serve "${common[@]}" "${chat[@]}" --port "$rport" --api-key-file "$keyfile"
    ;;
*) echo "Unknown RAG_MODE=$RAG_MODE" >&2; exit 1 ;;
esac
