#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=baktfold_download
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

VENV_DIR="/scratch/pawsey1018/edwa0468/software/pip/baktfold"
source $VENV_DIR/bin/activate

baktfold install -d baktfold_db -t 8
baktfold install -d baktfold_db --foldseek-gpu

