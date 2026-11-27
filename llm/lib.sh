# Shared helpers for the Setonix LLM launchers. Sourced, not executed.
# shellcheck shell=bash

# Pick a loopback port unique to this job: shared GPU nodes run several users'
# jobs at once, so a fixed port (8080, 11434) can collide with someone else's.
llm_port() { echo "${LLM_PORT:-$(( 20000 + SLURM_JOB_ID % 20000 ))}"; }

# CPU threads for the runtime: the physical cores in this allocation. On a
# Setonix GPU node one GCD pack is 8 cores = 16 hardware threads; the batch
# step may use all 16 but an `srun` step is bound to the 8 cores only (and
# SLURM_CPUS_ON_NODE reads 8 in the batch step but 16 in the srun step, so do
# not use it). Without an explicit count both runtimes default to the node's 64
# physical cores, oversubscribing the step; Ollama v0.40.18's bundled server
# then generates ~40% slower (23 vs 40 tok/s, Qwen3-32B Q4_K_M, one GCD).
llm_threads() {
    local tpc
    tpc=$(lscpu | awk -F: '/Thread\(s\) per core/ {gsub(/ /, "", $2); print $2}')
    echo "${LLM_THREADS:-$(( $(nproc) / ${tpc:-1} ))}"
}

# Wait until URL answers with HTTP 200, or the server PID dies, or timeout.
llm_wait_ready() {  # url pid timeout_s
    local url=$1 pid=$2 limit=${3:-1200} t0=$SECONDS
    until curl -fsS -o /dev/null "$url" 2>/dev/null; do
        kill -0 "$pid" 2>/dev/null || { echo "Server exited before becoming ready" >&2; return 1; }
        (( SECONDS - t0 > limit )) && { echo "Server not ready after ${limit}s" >&2; return 1; }
        sleep 2
    done
    echo "Ready after $(( SECONDS - t0 ))s: $url"
}

# Print the provenance block every validation record needs.
llm_provenance() {
    echo "date=$(date -Is) node=$(hostname) job=$SLURM_JOB_ID"
    echo "alloc: $(scontrol show job "$SLURM_JOB_ID" | grep -oE 'AllocTRES=[^ ]+')"
    echo "ROCR_VISIBLE_DEVICES=${ROCR_VISIBLE_DEVICES:-} amdgpu_driver=$(cat /sys/module/amdgpu/version 2>/dev/null)"
    rocm-smi --showproductname 2>/dev/null | grep -E 'Card (series|SKU)|GFX Version' | head -3
    echo "model=$MODEL_GGUF sha256=$MODEL_SHA256 ($MODEL_REPO@$MODEL_REVISION)"
}

# Sample GPU VRAM in use and the host RSS of a named process every few seconds
# into a TSV, in the background. Prints the sampler PID.
llm_start_monitor() {  # out.tsv process-name-regex
    local out=$1 re=$2
    printf 'time_s\tvram_used_mib\thost_rss_mib\n' > "$out"
    (
        t0=$SECONDS
        while :; do
            vram=$(rocm-smi --showmeminfo vram 2>/dev/null \
                   | awk -F': ' '/Total Used Memory/ {s += $NF} END {printf "%d", s / 1048576}')
            rss=$(ps -u "$USER" -o rss=,comm= | awk -v re="$re" '$2 ~ re {s += $1} END {printf "%d", s / 1024}')
            printf '%d\t%s\t%s\n' $(( SECONDS - t0 )) "$vram" "$rss" >> "$out"
            sleep 3
        done
    ) >/dev/null 2>&1 &   # detach stdout, or $(llm_start_monitor ...) never returns
    echo $!
}

llm_monitor_summary() {  # out.tsv
    awk -F'\t' 'NR > 1 { if ($2 > v) v = $2; if ($3 > r) r = $3 } END {
        printf "peak VRAM used %d MiB; peak host RSS %d MiB\n", v, r }' "$1"
}

# Stop a server started under srun and confirm nothing is left on the GPU.
llm_stop() {  # pid process-name-regex
    local pid=$1 re=$2
    kill -TERM "$pid" 2>/dev/null || true
    for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    kill -0 "$pid" 2>/dev/null && { echo "Server still alive after 30s; killing" >&2; kill -KILL "$pid"; }
    wait "$pid" 2>/dev/null || true
    sleep 2
    if pgrep -u "$USER" -f "$re" >/dev/null; then
        echo "WARNING: leftover processes:"; pgrep -u "$USER" -af "$re"
    else
        echo "Clean shutdown: no $re processes left"
    fi
    echo "VRAM used after shutdown: $(rocm-smi --showmeminfo vram 2>/dev/null \
        | awk -F': ' '/Total Used Memory/ {s += $NF} END {printf "%d", s / 1048576}') MiB"
}

llm_tunnel_hint() {  # port
    cat <<HINT
To connect from your own computer (replace USER):
  ssh -N -L $1:127.0.0.1:$1 -J USER@setonix.pawsey.org.au USER@$(hostname)
then use http://127.0.0.1:$1 locally. Cancel the job (scancel $SLURM_JOB_ID) when finished.
HINT
}
