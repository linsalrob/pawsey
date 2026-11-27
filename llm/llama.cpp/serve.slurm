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
: "${LLAMA_SERVER:?Set the absolute path to llama-server}"
: "${MODEL_GGUF:?Set the absolute GGUF path}"
[[ -x "$LLAMA_SERVER" && -r "$MODEL_GGUF" ]] || { echo "Missing executable or model" >&2; exit 1; }
srun --ntasks=1 --gpus-per-task=1 "$LLAMA_SERVER" \
  --model "$MODEL_GGUF" --n-gpu-layers 99 --ctx-size 4096 --parallel 1 \
  --host 127.0.0.1 --port 8080
