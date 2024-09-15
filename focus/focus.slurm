#!/bin/bash
#SBATCH --job-name=focus
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH -o focus-%A_%a.out
#SBATCH -e focus-%A_%a.err

set -euo pipefail


module load pawseyenv/2023.08

module load singularity/3.11.4-slurm
singularity exec --bind $PWD/:/focus \
	/home/edwa0468/Projects/focus/sif/focus_v1.8.0_d95c4fb1ae57.sif \
	focus -q /focus/fasta -o /focus/focus -k 7 -t 16

