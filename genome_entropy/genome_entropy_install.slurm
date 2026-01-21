#!/bin/bash
#SBATCH --account=pawsey1018-gpu
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu-dev
#SBATCH --job-name=ge_install
#SBATCH --time=0-1
#SBATCH --ntasks=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

eval "$(conda shell.bash hook)"
TMP=305294afb2c8
if [[ ! -e /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP ]]; then echo "Please define the conda environment" >&2; exit 1; fi
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

pip install genome_entropy
