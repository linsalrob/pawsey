#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=Koverage
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=64GB
#SBATCH -o koverage_all-%j.out
#SBATCH -e koverage_all-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate snakemake7

snakemake --profile pawsey -s /home/edwa0468/GitHubs/pawsey/snakemakes/koverage.snakefile --local-cores 12

