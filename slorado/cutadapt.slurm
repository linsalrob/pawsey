#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=CutAdapt
#SBATCH --time=0-2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/trimming

# Define input and output paths
FASTQ_DIR="fastq"
BARCODES="ONT_Rapid_Barcodes.fna"
OUTPUT_DIR="demuxed_reads"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Loop through each FASTQ file in the directory
for fq in "${FASTQ_DIR}"/*.fastq; do
    base=$(basename "${fq}" .fastq)
    
    echo "Processing ${base}.fastq ..."
    
    cutadapt \
      -j 0 \
      -e 0.1 \
      --action=trim \
      --front file:${BARCODES} \
      --untrimmed-output="${OUTPUT_DIR}/${base}_unassigned.fastq" \
      -o "${OUTPUT_DIR}/${base}_barcode_{name}.fastq" \
      "${fq}"
    
    echo "Finished ${base}.fastq"
done

echo "Demultiplexing complete! Output is in ${OUTPUT_DIR}/"

