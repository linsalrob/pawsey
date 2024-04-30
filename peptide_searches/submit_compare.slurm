#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=searchingGFA
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128GB
#SBATCH -o searchGFA-%j.out
#SBATCH -e searchGFA-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate snakemake7

snakemake -s searchGFA.snakefile --profile pawsey --local-cores 32

