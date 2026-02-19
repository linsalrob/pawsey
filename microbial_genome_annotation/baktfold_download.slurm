#!/bin/bash
#SBATCH --account=pawsey1018-gpu
#SBATCH --job-name=baktfold_download
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu-dev
#SBATCH --job-name=bk_db
#SBATCH --time=0-4
#SBATCH --ntasks=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err


set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

VENV_DIR="/scratch/pawsey1018/edwa0468/software/pip/baktfold"
source $VENV_DIR/bin/activate

baktfold install -d ~/Databases/baktfold_db -t 8
baktfold install -d ~/Databases/baktfold_db --foldseek-gpu

