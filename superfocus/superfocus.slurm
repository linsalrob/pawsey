#!/bin/bash
#SBATCH --job-name=superfocus
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH -o superfocus-%A_%a.out
#SBATCH -e superfocus-%A_%a.err

set -euo pipefail


module load pawseyenv/2023.08

module load singularity/3.11.4-slurm
singularity exec --bind $PWD/:/superfocus,/home/edwa0468/Projects/superfocus_db:/superfocus_db sif/superfocus_v1.6.0_5abbef95a6ca.sif \
	superfocus -q /superfocus/fasta -t 16 -dir /superfocus/superfocus -a mmseqs2 -db DB_95 -b /superfocus_db -o ERZ477431

