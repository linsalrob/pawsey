#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=minimap
#SBATCH --time=0-2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=128G
#SBATCH -o minimap-%j.out
#SBATCH -e minimap-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/minimap

FASTQ_DIR="to_assemble"
ASS_DIR="assembled"

for fq in "${FASTQ_DIR}"/*.fastq; do
    base=$(basename "${fq}" .fastq)
    ASS="${ASS_DIR}/$base/assembly.fasta"
    OUT="${ASS_DIR}/$base/reads_contigs.bam"
    if [[ ! -e $ASS ]]; then 
	echo "$fq not assembled. Skipping" >&2;
	continue
    fi
    echo "Mapping $fq to $ASS"
    minimap2 -t 32 -ax map-ont $ASS $fq | samtools view -F 3584 -b --threads 16  | samtools sort -@ 16 -o $OUT -
done

