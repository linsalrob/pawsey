#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=taxonomy_check
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Read-level taxonomic composition, for all reads and separately for the reads
# that did not map to the candidate chromosome. If the sample were a two-organism
# mixture, the unmapped fraction should be dominated by a different taxon.
# Usage: taxonomy_check.slurm <sample name>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

SAMPLE=$1
BASE=${PROJECT_DIR:-$PWD}
R=$BASE/${RESDIR:-rescue}/$SAMPLE/mixture
SKETCH=/home/edwa0468/Databases/mash/refseq.genomes.k21s1000.msh
THREADS=${SLURM_CPUS_PER_TASK:-8}

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/microbial_annotations

cd "$R"
echo "### all reads"
mash screen -p "$THREADS" -w "$SKETCH" "$BASE/${READDIR:-reads}/$SAMPLE.fastq.gz" > mash_all.tsv 2> mash_all.log
sort -gr mash_all.tsv > mash_all_sorted.tsv
head -15 mash_all_sorted.tsv | cut -f1,5

echo "### unmapped reads"
samtools fastq -f 4 -@ 8 reads_vs_ref.bam 2>/dev/null | gzip > unmapped.fastq.gz
n=$(( $(zcat unmapped.fastq.gz | wc -l) / 4 ))
echo "unmapped reads: $n"
if (( n > 100 )); then
	mash screen -p "$THREADS" -w "$SKETCH" unmapped.fastq.gz > mash_unmapped.tsv 2> mash_unmapped.log
	sort -gr mash_unmapped.tsv > mash_unmapped_sorted.tsv
	head -15 mash_unmapped_sorted.tsv | cut -f1,5
	# length profile: short junk reads look different from a second genome
	zcat unmapped.fastq.gz | awk 'NR%4==2{n++; t+=length($0); if(length($0)>m)m=length($0)}
		END{printf "unmapped_reads\t%d\nunmapped_bases\t%d\nunmapped_mean_len\t%.0f\nunmapped_max_len\t%d\n", n,t,t/n,m}' \
		> unmapped_stats.tsv
	cat unmapped_stats.tsv
fi
echo "### done"
