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
TMP=7199822bc36d
conda activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/$TMP

# Define input and output paths
FASTQ_DIR="fastq"
OUTPUT_DIR="demuxed_reads"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Loop through each FASTQ file in the directory
for fq in "${FASTQ_DIR}"/*.fastq; do
    base=$(basename "${fq}" .fastq)
    
    echo "Processing ${base}.fastq ... at " `date`

    barbell kit -k SQK-RBK114-96 -i ${fq} -o $OUTPUT_DIR
    
    echo "Finished ${base}.fastq ... at " `date`
done

echo "Demultiplexing complete! Output is in ${OUTPUT_DIR}/"

