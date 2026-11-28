#!/bin/bash
# Install the pinned Ollama release into user space (no root, no systemd).
# Downloads the generic and ROCm archives on the copy partition, verifies the
# upstream SHA256 for each, and extracts them into OLLAMA_PREFIX. Usage:
#   sbatch --account="$PAWSEY_PROJECT" --export=ALL llm/ollama/install.slurm
#SBATCH --job-name=llm-ollama-install
#SBATCH --partition=copy
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=%x-%j.out
set -euo pipefail
HERE=${LLM_DIR:-${SLURM_SUBMIT_DIR:-.}/llm}
# shellcheck source=../versions.env
source "$HERE/versions.env"

if [[ -x $OLLAMA_PREFIX/bin/ollama ]]; then
    echo "Already installed: $OLLAMA_PREFIX"; "$OLLAMA_PREFIX/bin/ollama" --version || true; exit 0
fi
dl=$LLM_ROOT/downloads/ollama-$OLLAMA_VERSION
mkdir -p "$dl"
base=https://github.com/ollama/ollama/releases/download/$OLLAMA_VERSION
fetch() {  # fetch <file> <sha256>
    local f=$1 sum=$2
    if ! { [[ -s $dl/$f ]] && echo "$sum  $dl/$f" | sha256sum -c --status; }; then
        curl -fsSL --retry 5 --retry-delay 30 -o "$dl/$f" "$base/$f"
    fi
    echo "$sum  $dl/$f" | sha256sum -c
}
fetch ollama-linux-amd64.tar.zst      "$OLLAMA_SHA256_MAIN"
fetch ollama-linux-amd64-rocm.tar.zst "$OLLAMA_SHA256_ROCM"

# Extract into a temporary directory and rename on success, so a failed
# install never leaves a half-populated prefix that looks complete.
tmp=$OLLAMA_PREFIX.incomplete-$$
mkdir -p "$tmp"
# The generic archive also carries NVIDIA CUDA libraries, which are useless on
# Setonix; skip them to save ~4 GB and several hundred files.
tar --zstd -xf "$dl/ollama-linux-amd64.tar.zst" -C "$tmp" --wildcards --exclude='lib/ollama/cuda_*'
tar --zstd -xf "$dl/ollama-linux-amd64-rocm.tar.zst" -C "$tmp"
mv "$tmp" "$OLLAMA_PREFIX"
"$OLLAMA_PREFIX/bin/ollama" --version || true
ls "$OLLAMA_PREFIX/lib/ollama"
du -sh "$OLLAMA_PREFIX"; find "$OLLAMA_PREFIX" -type f | wc -l
echo "Installed Ollama $OLLAMA_VERSION into $OLLAMA_PREFIX"
