#!/bin/bash
#SBATCH --account=pawsey1018-gpu
#SBATCH --job-name=bk_run
#SBATCH --gres=gpu:8
#SBATCH --partition=gpu
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [[ $# -ne 2 ]]; then
	echo "$0 <bakta json file> <output directory>" >&2;
	exit 1;
fi

VENV_DIR="/scratch/pawsey1018/edwa0468/software/pip/baktfold"
source $VENV_DIR/bin/activate

baktfold run -i $1 -o $2 -d ~/Databases/baktfold_db -f -t 16 

