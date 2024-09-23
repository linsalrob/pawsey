#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=SRA_dld
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64GB
#SBATCH -o SRA_dld-%j.out
#SBATCH -e SRA_dld-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate snakemake7

snakemake -s sra_download.fasta.snakefile --profile pawsey --local-cores 8 --jobs 10

