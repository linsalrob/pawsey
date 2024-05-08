#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=megahit
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32GB
#SBATCH -o megahit-%j.out
#SBATCH -e megahit-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate snakemake7

snakemake -s megahit.snakefile --profile pawsey --local-cores 8
