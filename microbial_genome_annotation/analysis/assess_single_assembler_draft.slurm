#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=assess_flye
#SBATCH --partition=work
#SBATCH --time=06:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Assess a single-assembler Flye draft: circularity, per-contig coverage,
# contamination, and structural support from the other independent assemblies.
# Usage: assess_flye_draft.slurm <sample name>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

SAMPLE=$1
BASE=${PROJECT_DIR:-$PWD}
D=$BASE/${RESDIR:-rescue}/$SAMPLE_flye
THREADS=${SLURM_CPUS_PER_TASK:-8}
cd "$D"

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc

echo "### coverage of the draft by all reads"
minimap2 -ax map-ont -t "$THREADS" flye_01.fasta "$BASE/${READDIR:-reads}/$SAMPLE.fastq.gz" 2> minimap2.log \
	| samtools sort -@ 8 -o reads_vs_draft.bam -
samtools index reads_vs_draft.bam
samtools flagstat -@ 8 reads_vs_draft.bam > flagstat.txt
samtools coverage reads_vs_draft.bam | sort -k3,3nr > per_contig_coverage.tsv
head -12 per_contig_coverage.tsv | column -t

echo "### structural support: flye_01 against the other independent assemblies"
{
printf "comparison\tref_len\tqry_len\tavg_identity\tref_aligned_pct\tqry_aligned_pct\n"
for q in "$BASE"/assembly/$SAMPLE/assemblies/{flye_03,myloasm_01,raven_01,canu_01,necat_01,metamdbg_01}.fasta; do
	[[ -s "$q" ]] || continue
	tag=$(basename "$q" .fasta)
	dnadiff -p "sup_$tag" flye_01.fasta "$q" >/dev/null 2>&1 || continue
	awk -v t="$tag" '
	  /^TotalBases/   {rl=$2; ql=$3}
	  /^AlignedBases/ {ra=$2; qa=$3}
	  /^AvgIdentity/  {if(id=="") id=$2}
	  END{match(ra,/\(([0-9.]+)%\)/,a); match(qa,/\(([0-9.]+)%\)/,b);
	      printf "%s\t%s\t%s\t%s\t%s\t%s\n", t, rl, ql, id, a[1], b[1]}' "sup_$tag.report"
done
} > structural_support.tsv
column -t structural_support.tsv

echo "### contamination: taxonomic composition"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/microbial_annotations
SKETCH=/home/edwa0468/Databases/mash/refseq.genomes.k21s1000.msh
mash screen -p "$THREADS" -w "$SKETCH" "$BASE/${READDIR:-reads}/$SAMPLE.fastq.gz" > mash_all.tsv 2> mash.log
sort -gr mash_all.tsv > mash_all_sorted.tsv
head -10 mash_all_sorted.tsv | cut -f1,2,5
echo "### done"
