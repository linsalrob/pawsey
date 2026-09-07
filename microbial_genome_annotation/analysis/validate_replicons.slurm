#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=validate_replicons
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Map all reads to a curated consensus and report per-replicon coverage and
# copy number relative to the chromosome. Used to test whether two unitigs that
# Autocycler placed in one cluster are actually distinct replicons.
# Usage: validate_replicons.slurm <sample> <fasta>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

SAMPLE=$1; FA=$2
BASE=${PROJECT_DIR:-$PWD}
D=$BASE/${RESDIR:-rescue}/$SAMPLE/replicon_validation
mkdir -p "$D"; cd "$D"
THREADS=${SLURM_CPUS_PER_TASK:-8}

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc

cp "$FA" consensus.fasta
minimap2 -ax map-ont -t "$THREADS" consensus.fasta "$BASE/${READDIR:-reads}/$SAMPLE.fastq.gz" 2> minimap2.log \
	| samtools sort -@ 8 -o reads.bam -
samtools index reads.bam
samtools flagstat -@ 8 reads.bam > flagstat.txt
samtools coverage reads.bam > per_replicon_coverage.tsv
column -t per_replicon_coverage.tsv
echo
awk 'NR==1{next} $3>1000000{chrom=$7} {print}' per_replicon_coverage.tsv > /dev/null
chrom=$(awk 'NR>1 && $3>1000000{print $7; exit}' per_replicon_coverage.tsv)
echo "copy number relative to the chromosome (depth ratio):"
awk -v c="$chrom" 'NR>1{printf "  %-6s %10s bp  depth %8.1f  coverage %6s%%  copy_number %.2f\n", $1,$3,$7,$6,$7/c}' per_replicon_coverage.tsv
echo
echo "overall mapping:"; grep -E "in total|mapped \(" flagstat.txt | head -2
