# Shared helpers for the Setonix LLM launchers. Sourced, not executed.
# shellcheck shell=bash

# Pick a free loopback port: shared GPU nodes run several users' jobs at once,
# so a fixed port (8080, 11434) can collide with someone else's. The job ID
# only seeds the search, because consecutive job IDs give adjacent seeds and a
# job needing two ports would otherwise take the next job's. Scanning for a
# port nothing is listening on also covers the ports other users hold.
llm_port() {  # [seed]
    local p=${1:-${LLM_PORT:-$(( 20000 + SLURM_JOB_ID % 20000 ))}} i
    for i in $(seq 200); do
        ss -ltnH "sport = :$p" 2>/dev/null | grep -q . || { echo "$p"; return 0; }
        p=$(( p + 1 > 39999 ? 20000 : p + 1 ))
    done
    echo "No free port near ${1:-seed}" >&2
    return 1
}

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

# Total VRAM in use on the GPUs this job can see. Slurm's cgroup exposes only
# the allocation's GCDs to rocm-smi, so this is already scoped to the job; with
# several GPUs allocated it is their sum, which is what the launchers want.
llm_vram_used_mib() {
    rocm-smi --showmeminfo vram 2>/dev/null \
        | awk -F': ' '/Total Used Memory/ {s += $NF} END {printf "%d", s / 1048576}'
}

# Processes of this job only, matching a name regex. `ps -u $USER` spans the
# whole node, and GPU nodes are shared, so another of your own jobs on the same
# node would otherwise be counted too. Slurm puts every process of a job in a
# cgroup named job_<id>, including srun steps, which are not descendants of
# this script. Prints "pid rss_kib" per line. The regex matches the process
# name, or the whole command line with -f (as `pgrep -f` does).
llm_job_procs() {  # [-f] process-name-regex
    local fmt=comm= re=$1
    if [[ $1 == -f ]]; then fmt=args= re=$2; fi
    ps -u "$USER" -o pid=,rss=,"$fmt" | awk -v re="$re" \
        '{ name = ""; for (i = 3; i <= NF; i++) name = name (i > 3 ? " " : "") $i
           if (name ~ re) print $1, $2 }' | while read -r pid rss; do
        if grep -qs "job_${SLURM_JOB_ID}\b" "/proc/$pid/cgroup"; then echo "$pid $rss"; fi
    done
    # Matching nothing is a normal result, not a failure: the callers run
    # under `set -e`, and the trap that stops a server calls this last.
    return 0
}

# Sample GPU VRAM in use and the host RSS of this job's matching processes every
# few seconds into a TSV, in the background. Prints the sampler PID.
llm_start_monitor() {  # out.tsv process-name-regex
    local out=$1 re=$2
    printf 'time_s\tvram_used_mib\thost_rss_mib\n' > "$out"
    (
        t0=$SECONDS
        while :; do
            vram=$(llm_vram_used_mib)
            rss=$(llm_job_procs "$re" | awk '{s += $2} END {printf "%d", s / 1024}')
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
    local left
    left=$(llm_job_procs -f "$re")
    if [[ -n $left ]]; then
        echo "WARNING: leftover processes in this job:"
        echo "$left" | while read -r p _; do ps -o pid=,args= -p "$p"; done
    else
        echo "Clean shutdown: no $re processes left"
    fi
    echo "VRAM used after shutdown: $(llm_vram_used_mib) MiB"
}

llm_tunnel_hint() {  # port
    cat <<HINT
To connect from your own computer (replace USER):
  ssh -N -L $1:127.0.0.1:$1 -J USER@setonix.pawsey.org.au USER@$(hostname)
then use http://127.0.0.1:$1 locally. Cancel the job (scancel $SLURM_JOB_ID) when finished.
HINT
}
