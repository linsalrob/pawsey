#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=CutAdapt
#SBATCH --time=0-2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o cutadapt-%j.out
#SBATCH -e cutadapt-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
# TMP is a temp conda environment with cutadapt installed
TMP=108aa9c8a6f0
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

# Define input and output paths
FASTQ_DIR="fastq_sup"
BARCODES="ONT_Rapid_Barcodes.fna"
OUTPUT_DIR="demuxed_reads_sup"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Loop through each FASTQ file in the directory
for fq in "${FASTQ_DIR}"/*.fastq; do
    base=$(basename "${fq}" .fastq)
    
    echo "Processing ${base}.fastq ..."
    
    cutadapt \
      -e 0.1 \
      --action=trim \
      --front file:${BARCODES} \
      --untrimmed-output="${OUTPUT_DIR}/${base}_unassigned.fastq" \
      -o "${OUTPUT_DIR}/${base}_barcode_{name}.fastq" \
      "${fq}"
    
    echo "Finished ${base}.fastq"
done

echo "Demultiplexing complete! Output is in ${OUTPUT_DIR}/"

