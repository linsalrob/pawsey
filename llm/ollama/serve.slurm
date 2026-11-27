#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu-dev
#SBATCH --time=00:30:00
#SBATCH --output=%x-%j.out
set -euo pipefail
: "${SLURM_JOB_ID:?Submit this launcher with sbatch}"
hostname
: "${OLLAMA_BIN:?Set the absolute path to ollama}"
: "${OLLAMA_MODELS:?Set a model cache directory outside Git}"
[[ -x "$OLLAMA_BIN" ]] || { echo "Missing Ollama executable" >&2; exit 1; }
mkdir -p "$OLLAMA_MODELS"
export OLLAMA_MODELS
export OLLAMA_HOST=127.0.0.1:11434
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_CONTEXT_LENGTH=4096
srun --ntasks=1 --gpus-per-task=1 "$OLLAMA_BIN" serve
