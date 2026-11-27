#!/bin/bash
# Serve the pinned GGUF with Ollama on one MI250X GCD.
#
#   sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/ollama/serve.slurm
#       serves until the walltime or `scancel`; the log prints the tunnel command.
#   LLM_BENCH=1 sbatch --account="${PAWSEY_PROJECT}-gpu" --export=ALL llm/ollama/serve.slurm
#       imports the GGUF if needed, runs the matched prompt benchmark, then stops.
#
# Ollama has no authentication. It listens on compute-node loopback only, but
# other users' jobs on a shared GPU node can reach that port. Do not send
# confidential prompts to it unless the node is yours alone (sbatch --exclusive).
#SBATCH --job-name=llm-ollama
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

# Do not load a rocm module: Ollama ships and uses its own ROCm user-space
# libraries (lib/ollama/rocm_v*), and a module's LD_LIBRARY_PATH could shadow them.
ollama=$OLLAMA_PREFIX/bin/ollama
[[ -x $ollama ]] || { echo "Missing $ollama; run llm/ollama/install.slurm" >&2; exit 1; }
[[ -r $MODEL_GGUF ]] || { echo "Missing $MODEL_GGUF; run llm/fetch_model.slurm" >&2; exit 1; }
llm_provenance

out=$LLM_ROOT/runs/ollama-$SLURM_JOB_ID
mkdir -p "$out" "$OLLAMA_MODELS"
port=$(llm_port)
export OLLAMA_HOST=127.0.0.1:$port OLLAMA_MODELS
# Matched settings (see llm/README.md): one request, one model, LLM_CTX context,
# flash attention on, f16 KV cache; keep the model loaded for the whole job.
export OLLAMA_NUM_PARALLEL=1 OLLAMA_MAX_LOADED_MODELS=1 OLLAMA_CONTEXT_LENGTH=$LLM_CTX
export OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=f16 OLLAMA_KEEP_ALIVE=-1
export OLLAMA_NOHISTORY=1
# Only probe the bundled ROCm backend (skip Vulkan and CPU-only discovery).
export OLLAMA_LLM_LIBRARY=${OLLAMA_LLM_LIBRARY:-$(basename "$(ls -d "$OLLAMA_PREFIX"/lib/ollama/rocm_v* | tail -1)")}
export OLLAMA_VULKAN=0
OLLAMA_NAME=${OLLAMA_NAME:-qwen3-32b-q4km}

# Ollama gives GPU discovery a fixed 30 s (discover/runner.go). Loading its
# ~2.4 GB of ROCm libraries cold from /scratch can take longer, and Ollama then
# silently falls back to the CPU. Read them once into the page cache first.
echo "Warming page cache for $OLLAMA_LLM_LIBRARY libraries"; tw=$SECONDS
find "$OLLAMA_PREFIX/lib/ollama" -maxdepth 1 -type f -name '*.so*' -print0 | xargs -0 cat > /dev/null
find "$OLLAMA_PREFIX/lib/ollama/$OLLAMA_LLM_LIBRARY" -type f \( -name '*.so*' -o -name '*gfx90a*' \) \
    -print0 | xargs -0 cat > /dev/null
echo "warm_s=$(( SECONDS - tw ))"

mon=$(llm_start_monitor "$out/memory.tsv" 'ollama|llama-server')
srun --ntasks=1 --gpus-per-task=1 "$ollama" serve > "$out/server.log" 2>&1 &
pid=$!
trap 'llm_stop "$pid" "ollama (serve|runner)"; kill "$mon" 2>/dev/null || true' EXIT
llm_wait_ready "http://$OLLAMA_HOST/api/version" "$pid" 300
"$ollama" --version
grep -E 'inference compute' "$out/server.log" || true
if ! grep -qiE 'inference compute.*library=rocm' "$out/server.log"; then
    echo "ERROR: Ollama found no ROCm GPU and would run on the CPU; see $out/server.log" >&2
    exit 1
fi

# Import the same GGUF once, as a base model. Ollama copies it into
# OLLAMA_MODELS as a blob (a second ~20 GB on disk); later jobs reuse it.
if ! "$ollama" show "$OLLAMA_NAME-base" >/dev/null 2>&1; then
    printf 'FROM %s\n' "$MODEL_GGUF" > "$out/Modelfile.base"
    ti=$SECONDS
    "$ollama" create "$OLLAMA_NAME-base" -f "$out/Modelfile.base" 2>&1 | tail -1
    echo "import_s=$(( SECONDS - ti ))"
fi
# The served model adds this allocation's settings on top of the base. This is
# instant (no blob copy). Ollama has no server-wide thread setting, and without
# num_thread its runner uses all 64 node cores (see llm_threads in lib.sh).
threads=$(llm_threads)
printf 'FROM %s\nPARAMETER num_ctx %s\nPARAMETER num_thread %s\n' \
    "$OLLAMA_NAME-base" "$LLM_CTX" "$threads" > "$out/Modelfile"
"$ollama" create "$OLLAMA_NAME" -f "$out/Modelfile" 2>&1 | tail -1
"$ollama" show "$OLLAMA_NAME"
"$ollama" show --modelfile "$OLLAMA_NAME" > "$out/modelfile.txt"
echo "Imported blob checksum (should equal MODEL_SHA256):"
grep -m1 -oE 'sha256-[0-9a-f]{64}' "$out/modelfile.txt" || true
llm_tunnel_hint "$port"

if [[ ${LLM_BENCH:-0} == 1 ]]; then
    PY=$(command -v python3.11 || command -v python3)
    "$PY" "$HERE/bench/bench.py" --api ollama --url "http://$OLLAMA_HOST" \
        --model "$OLLAMA_NAME" --ctx "$LLM_CTX" \
        --prompts "$HERE/bench/prompts.jsonl" --out "$out/bench.jsonl"
    "$ollama" ps | tee "$out/ollama-ps.txt"
    grep -E 'offloaded|model buffer size|KV|flash|n_ctx' "$out/server.log" | head -20 || true
    sleep 4
    llm_monitor_summary "$out/memory.tsv"
    echo "Results in $out"
else
    wait "$pid"
fi
