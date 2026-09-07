#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=plasmid_variants
#SBATCH --partition=work
#SBATCH --time=06:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Find variants in the plasmids that are real rather than ONT basecalling
# artefacts.
#
# The design point is that the same molecules recur across samples: the
# 3,400 bp plasmid is carried by all five plasmid samples, the 5,740 bp by
# three of them. Every sample's reads are mapped to one common reference per
# plasmid family, INCLUDING the sample the reference came from. That gives the
# discriminator:
#
#   * a site where even the reference sample's own reads disagree with its own
#     assembly is an error-prone site - systematic basecalling error;
#   * a site where the reference sample's reads agree with the assembly but
#     another sample's reads carry an alternative allele is a real difference
#     between samples.
#
# Strand balance and homopolymer context are recorded alongside, since ONT
# error is concentrated in homopolymers and is frequently strand-biased,
# whereas a genuine variant should appear on both strands roughly equally.
#
# Usage: plasmid_variants.slurm <plasmids dir> <reads dir> <out dir>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

PLASDIR=${1:-plasmids}
READDIR=${2:-reads}
OUT=${3:-plasmid_variants}
BASE=${PROJECT_DIR:-$PWD}
THREADS=${SLURM_CPUS_PER_TASK:-8}
cd "$BASE"
mkdir -p "$OUT/refs" "$OUT/bam" "$OUT/vcf"

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc

# ---------------------------------------------------------------- references
# group the assembled plasmids into families by length, and pick one reference
# per family from the sample with the deepest coverage of it
python3 "$(dirname "$0")"/variant_families.py "$PLASDIR" "$OUT" | tee "$OUT/families.txt"

# --------------------------------------------------------------- map + call
while read -r fam ref_bc reflen; do
	[[ -z "$fam" ]] && continue
	REF=$OUT/refs/${fam}.fasta
	samtools faidx "$REF"
	for SUB in "$READDIR"/sample*_sub*Mbp.fastq.gz; do
		bc=$(basename "$SUB" | sed 's/_sub.*//')
		grep -q "^${bc}$" "$OUT/${fam}.carriers" || continue
		BAM=$OUT/bam/${fam}_${bc}.bam
		if [[ ! -s $BAM ]]; then
			minimap2 -ax map-ont -t "$THREADS" "$REF" "$SUB" 2>/dev/null \
				| samtools sort -@ 8 -o "$BAM" -
			samtools index "$BAM"
		fi
		# ADF/ADR give per-strand allele depths, needed for the strand-bias test
		bcftools mpileup -f "$REF" -a FORMAT/AD,FORMAT/ADF,FORMAT/ADR \
			-B -Q 10 -q 10 --max-depth 5000 --threads 8 "$BAM" 2>/dev/null \
			| bcftools call -m -A --threads 8 -Ov 2>/dev/null \
			| bcftools norm -f "$REF" -Ov 2>/dev/null \
			> "$OUT/vcf/${fam}_${bc}.vcf"
		echo "  $fam $bc done"
	done
done < "$OUT/families.tsv"

# --------------------------------------------------------------- classify
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc
python3 "$(dirname "$0")"/classify_variants.py "$OUT"
echo "### done"
