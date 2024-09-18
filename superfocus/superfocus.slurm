#!/bin/bash
#SBATCH --job-name=superfocus
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH -o superfocus-%j.out
#SBATCH -e superfocus-%j.err

set -euo pipefail


module load pawseyenv/2023.08

module load singularity/3.11.4-slurm

TMP=$(mktemp -d -p .)
EPROJ=DRR001
singularity exec --bind $PWD/:/superfocus,/home/edwa0468/Projects/superfocus_db:/superfocus_db \
                                /home/edwa0468/Projects/superfocus/sif/superfocus_v1.6.0_b91c0c41d6a5.sif \
                                superfocus -q /superfocus/$EPROJ/fasta -t 16 -dir /superfocus/$EPROJ/${EPROJ}_superfocus \
                                        -a mmseqs2 -db DB_95 -b /superfocus_db -d -o $EPROJ -tmp /superfocus/$TMP

