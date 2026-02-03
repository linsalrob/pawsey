#!/bin/bash
#SBATCH --job-name=ge_run
#SBATCH --account=pawsey1018-gpu
#SBATCH --gres=gpu:8
#SBATCH --partition=gpu
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH -o slurm/%x-%j.out
#SBATCH -e slurm/%x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR



VENV_DIR="/scratch/pawsey1018/edwa0468/software/pip/genome_entropy"
if [[ ! -e "$VENV_DIR" ]]; then 
	echo "Please run the installer to create the venv" >&2;
	exit 1;
fi

source "$VENV_DIR/bin/activate"

ENCSZ=20000

if [[ $# -ne 2 ]]; then
	echo "$0 <genbank file> <output file>" >&2;
	exit 1;
fi

genome_entropy run -g $1 -o $2 --multi-gpu --encoding-size $ENCSZ
