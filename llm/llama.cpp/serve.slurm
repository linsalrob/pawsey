#!/bin/bash
# Serve the pinned GGUF with llama.cpp's llama-server on one MI250X GCD.
#
#   sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/llama.cpp/serve.slurm
#       serves until the walltime or `scancel`; the log prints the tunnel command.
#   LLM_BENCH=1 sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/llama.cpp/serve.slurm
#       runs llama-bench and the matched prompt benchmark, then stops (validation).
#
# The server listens on compute-node loopback only and requires an API key,
# because other users' jobs can share the node. The key is written to
# $LLM_ROOT/llama-server.key (mode 600); send it as `Authorization: Bearer <key>`.
#SBATCH --job-name=llm-llamacpp
#SBATCH --partition=gpu-dev
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --output=%x-%j.out
set -euo pipefail
: "${SLURM_JOB_ID:?Submit this launcher with sbatch}"
HERE=${LLM_DIR:-${SLURM_SUBMIT_DIR:-.}/llm}
# shellcheck source=../versions.env
source "$HERE/versions.env"
# shellcheck source=../lib.sh
source "$HERE/lib.sh"

module load "$LLAMA_ROCM_MODULE"
server=$LLAMA_PREFIX/bin/llama-server
[[ -x $server ]] || { echo "Missing $server; run llm/llama.cpp/build.slurm" >&2; exit 1; }
[[ -r $MODEL_GGUF ]] || { echo "Missing $MODEL_GGUF; run llm/fetch_model.slurm" >&2; exit 1; }
llm_provenance
cat "$LLAMA_PREFIX/BUILD_INFO"

out=$LLM_ROOT/runs/llamacpp-$SLURM_JOB_ID
mkdir -p "$out"
port=$(llm_port)
threads=$(llm_threads)
keyfile=$LLM_ROOT/llama-server.key
if [[ ! -s $keyfile ]]; then (umask 077; head -c 24 /dev/urandom | base64 > "$keyfile"); fi

# Matched settings (see llm/README.md): one slot, LLM_CTX context, all layers on
# the GPU, flash attention on, f16 KV cache, batch/ubatch 512 (Ollama's default),
# CPU threads = physical cores allocated (see llm_threads in lib.sh).
common=(--model "$MODEL_GGUF" --n-gpu-layers 999 --ctx-size "$LLM_CTX" --flash-attn on
        --batch-size 512 --ubatch-size 512 --threads "$threads")

if [[ ${LLM_BENCH:-0} == 1 ]]; then
    echo "== llama-bench (synthetic pp512 / tg128, no chat template)"
    srun --ntasks=1 --gpus-per-task=1 "$LLAMA_PREFIX/bin/llama-bench" -m "$MODEL_GGUF" \
        -ngl 999 -fa 1 -b 512 -ub 512 -t "$threads" -p 512 -n 128 -r 3 -o md | tee "$out/llama-bench.md"
fi

mon=$(llm_start_monitor "$out/memory.tsv" 'llama-server')
t0=$SECONDS
srun --ntasks=1 --gpus-per-task=1 "$server" "${common[@]}" --parallel 1 --jinja \
    --host 127.0.0.1 --port "$port" --api-key-file "$keyfile" \
    > "$out/server.log" 2>&1 &
pid=$!
trap 'llm_stop "$pid" llama-server; kill "$mon" 2>/dev/null || true' EXIT
llm_wait_ready "http://127.0.0.1:$port/health" "$pid" 1200
echo "cold_load_s=$(( SECONDS - t0 )) (process start to /health OK)"
grep -E 'offloaded|ROCm|HIP|gfx|model buffer size|KV|flash|n_ctx' "$out/server.log" | head -20 || true
llm_tunnel_hint "$port"
echo "API key file: $keyfile"

if [[ ${LLM_BENCH:-0} == 1 ]]; then
    PY=$(command -v python3.11 || command -v python3)
    "$PY" "$HERE/bench/bench.py" --api llamacpp --url "http://127.0.0.1:$port" \
        --api-key-file "$keyfile" --model "$MODEL_FILE" --ctx "$LLM_CTX" \
        --prompts "$HERE/bench/prompts.jsonl" --out "$out/bench.jsonl"
    sleep 4
    llm_monitor_summary "$out/memory.tsv"
    echo "Results in $out"
else
    wait "$pid"
fi
