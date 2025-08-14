#!/bin/bash
#SBATCH --job-name=spades
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o spades-%j.out
#SBATCH -e spades-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
if [[ ! -e /scratch/pawsey1018/edwa0468/software/miniconda3/spades ]]; then 
	conda create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/spades 'python>=3.12' spades
fi

conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/spades
if [[ $# -ne 3 ]]; then echo "$0  <R1> <R2> <output>"; exit; fi



spades.py -1 $1 -2 $2 -o $3


