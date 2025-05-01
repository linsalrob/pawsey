#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=flye
#SBATCH --time=0-2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=128G
#SBATCH -o flye-%j.out
#SBATCH -e flye-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
# TMP is a temp conda environment with spades installed
TMP=6661a912bbf4
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP


FASTQ_DIR="to_assemble"
mkdir -p assembled

# Loop through each FASTQ file in the directory
for fq in "${FASTQ_DIR}"/*.fastq; do
    base=$(basename "${fq}" .fastq)
    if [[ -e assembled/$base ]]; then 
    	continue
    fi
    echo "Assembling $fq into assembled/$base"
    flye  --nano-raw $fq --out-dir assembled/$base -t 64 --keep-haplotypes
done
