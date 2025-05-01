#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=Dorado
#SBATCH --time=0-2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o dorado-%j.out
#SBATCH -e dorado-%j.err

set -euo pipefail

DORADO=/scratch/$PAWSEY_ACCOUNT/$USER/slorado/dorado-0.9.6-linux-x64/bin/dorado

# Define input and output paths
FASTQ_DIR="fastq_sup"
OUTPUT_DIR="dorado_demux_sup_96"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

$DORADO demux --recursive --emit-fastq --kit-name SQK-RBK114-96 --output-dir $OUTPUT_DIR $FASTQ_DIR

echo "Demultiplexing complete! Output is in ${OUTPUT_DIR}/"

