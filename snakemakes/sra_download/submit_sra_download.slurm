#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=SRA_dld
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128GB
#SBATCH -o SRA_dld-%j.out
#SBATCH -e SRA_dld-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate snakemake7

snakemake -s sra_download.snakefile --profile pawsey --local-cores 32

# compress all the output files

find fastq -type f -not -name \*gz -exec pigz -p 32 {} \;
