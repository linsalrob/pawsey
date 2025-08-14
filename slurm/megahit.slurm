#!/bin/bash
#SBATCH --job-name=megahit
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o megahit-%j.out
#SBATCH -e megahit-%j.err

set -euo pipefail
eval "$(mamba shell.bash hook)"

if [[ $# -ne 3 ]]; then echo "$0  <R1> <R2> <output>"; exit; fi

# do we have a megahit path
MH=$(command -v megahit)
if [[ -z $MH ]]; then 
	TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
	mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP  'python>=3.12' megahit
	mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP
fi


megahit -1 $1 -2 $2 -o $3


