#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=barbell
#SBATCH --time=0-2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

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

echo "PLEASE CHECK THE BARBELL GITHUB, I THINK YOU CAN RUN ONE COMMAND TO PROCESS ALL FILES"

# Loop through each FASTQ file in the directory
SAMPLE=0
for fq in "${FASTQ_DIR}"/*.fastq; do
    base=$(basename "${fq}" .fastq)
    SAMPLE=$((SAMPLE + 1))
    echo "Processing ${base}.fastq ... at " `date`

    barbell kit -k SQK-RBK114-96 -i ${fq} -o ${OUTPUT_DIR}/${OUTPUT_DIR}_$SAMPLE
    
    echo "Finished ${base}.fastq ... at " `date`
done


echo "Demultiplexing complete! Output is in ${OUTPUT_DIR}/ Combining into single files"

mkdir -p tmp$$
find ${OUTPUT_DIR} -type f -name \*fastq -printf "%f\n" | awk '!s[$0]++' | while read -r f; do 
	echo $f; 
	find ${OUTPUT_DIR} -name $f -exec cat {} + | gzip -c > tmp$$/${f}.gz; 
	mv tmp$$/${f}.gz $OUTPUT_DIR;
done

rmdir tmp$$
echo "Output files are in $OUTPUT_DIR"

