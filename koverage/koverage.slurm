#!/bin/bash
#SBACTH --account=$PAWSEY_ACCOUNT
#SBATCH --job-name=koverage
#SBATCH --time=2:00:00
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=15GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

TMP=fa39f97c0a16

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

if [[ "$#" -ne 3 ]]; then
	echo "$0 <reads directory> <reference.fasta> <output_directory>" >&2;
	exit 1
fi

koverage run --reads $1 --ref $2 --output $3 --threads $SLURM_CPUS_PER_TASK 
