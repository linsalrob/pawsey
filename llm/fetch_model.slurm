#!/bin/bash
# Download the pinned GGUF on the data-transfer (copy) partition and verify it
# against the publisher's SHA256. Usage, from the root of this repository:
#   sbatch --account="$PAWSEY_PROJECT" llm/fetch_model.slurm
#   LLM_FETCH=embed sbatch --account="$PAWSEY_PROJECT" --export=ALL llm/fetch_model.slurm
#SBATCH --job-name=llm-fetch-model
#SBATCH --partition=copy
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=04:00:00
#SBATCH --output=%x-%j.out
set -euo pipefail
HERE=${LLM_DIR:-${SLURM_SUBMIT_DIR:-.}/llm}
# shellcheck source=versions.env
source "$HERE/versions.env"
# LLM_FETCH=embed fetches the retrieval embedding model instead of the chat model.
if [[ ${LLM_FETCH:-chat} == embed ]]; then
    MODEL_REPO=$EMBED_REPO MODEL_REVISION=$EMBED_REVISION MODEL_FILE=$EMBED_FILE
    MODEL_SHA256=$EMBED_SHA256 MODEL_LICENSE=$EMBED_LICENSE MODEL_GGUF=$EMBED_GGUF
fi

dest=$MODEL_GGUF
mkdir -p "$(dirname "$dest")"
if [[ -s $dest ]] && echo "$MODEL_SHA256  $dest" | sha256sum -c --status; then
    echo "Already present and verified: $dest"; exit 0
fi
url="https://huggingface.co/${MODEL_REPO}/resolve/${MODEL_REVISION}/${MODEL_FILE}"
echo "Downloading $url"
curl -fsSL --retry 5 --retry-delay 30 -C - -o "$dest.part" "$url"
echo "$MODEL_SHA256  $dest.part" | sha256sum -c
mv "$dest.part" "$dest"
echo "Verified $dest ($MODEL_REPO@$MODEL_REVISION, $MODEL_LICENSE)"
