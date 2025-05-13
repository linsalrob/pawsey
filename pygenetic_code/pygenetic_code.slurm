#!/bin/bash
#SBATCH --job-name=translating
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32GB
#SBATCH -o translating-%j.out
#SBATCH -e translating-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/pygenetic_code

if [[ $# -ne 2 ]]; then
	echo "$0 <fast[aq] file> <output file>" >&2
fi

echo "Running pygenetic_code -s $1 --threads 32  > $2";
pygenetic_code -s $1 --threads 32 > $2

