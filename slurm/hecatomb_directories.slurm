#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=Hecatomb
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32GB
#SBATCH -o slurm/hecatomb-%A_%a.out
#SBATCH -e slurm/hecatomb-%A_%a.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate /home/edwa0468/scratch_1018/software/miniconda3/hecatomb

READDIR=$(head -n $SLURM_ARRAY_TASK_ID directories.txt | tail -n 1)

cd $READDIR
hecatomb run --reads fastq --profile pawsey

