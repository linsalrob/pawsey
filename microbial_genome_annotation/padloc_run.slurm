#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=padloc
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# Identify antiviral defence systems with PADLOC.
# https://github.com/padlocbio/padloc
#
# PADLOC wants protein sequences and the matching feature coordinates, because
# defence systems are called from gene content AND synteny -- the genes have to
# be adjacent. Give it bakta's .faa together with bakta's .gff3; the pair must
# come from the same annotation run or the coordinates will not match the
# proteins.
#
# Passing a nucleotide FASTA instead makes PADLOC call genes itself with
# prodigal, which discards the bakta annotation and makes results
# non-comparable with the rest of this pipeline. Prefer the .faa/.gff3 pair.
#
# Usage: padloc_run.slurm <faa> <gff3> <output directory>
#        padloc_run.slurm <fna> <output directory>          (prodigal fallback)

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/padloc
DB_DIR="$HOME/Databases/padloc"

[[ -d "$DB_DIR" ]] || { echo "Error: PADLOC database missing at $DB_DIR; run padloc_install.slurm" >&2; exit 1; }

if [[ $# -eq 3 ]]; then
	FAA=$1; GFF=$2; OUT=$3
	[[ -s "$FAA" ]] || { echo "Error: '$FAA' missing or empty" >&2; exit 1; }
	[[ -s "$GFF" ]] || { echo "Error: '$GFF' missing or empty" >&2; exit 1; }
	mkdir -p "$OUT"

	# Two adjustments are needed before PADLOC will read a bakta GFF correctly.
	#
	# 1. bakta appends the genome sequence to the GFF after a '##FASTA' line.
	#    PADLOC reads the GFF with comment="#", which drops that marker line but
	#    not the sequence lines after it, so tens of thousands of sequence lines
	#    are parsed as malformed feature rows. Harmless to the result but it is
	#    the source of the parser warning, and it is wasted work.
	#
	# 2. PADLOC replaces a CDS's ID with its Name attribute whenever the CDS
	#    carries a 'pseudo' attribute, because in RefSeq and GenBank GFFs Name
	#    holds an identifier. bakta puts the PRODUCT DESCRIPTION in Name, so the
	#    substitution turns a locus tag into something like
	#    "DNA 3'-5' helicase", which then fails to match the protein in the .faa
	#    and PADLOC aborts with "N protein sequence IDs are missing from GFF
	#    file". It only triggers when a pseudogene happens to hit one of the
	#    defence HMMs, so it appears sporadically across a set of genomes.
	#
	#    Dropping the 'pseudo' attribute keeps the locus tag as the ID, so
	#    pseudogenes are carried through like any other CDS rather than being
	#    silently lost from the join.
	CLEAN_GFF="$OUT/$(basename "${GFF%.*}")_padloc_input.gff3"
	sed '/^##FASTA/,$d' "$GFF" | sed 's/;pseudo=[^;]*//; s/pseudo=[^;]*;//' > "$CLEAN_GFF"
	echo "Prepared GFF for PADLOC: $CLEAN_GFF" >&2
	echo "  feature lines: $(grep -vc '^#' "$CLEAN_GFF")" >&2
	echo "  pseudo attributes removed: $(grep -c 'pseudo=' "$GFF" || true) -> $(grep -c 'pseudo=' "$CLEAN_GFF" || true)" >&2

	padloc --faa "$FAA" --gff "$CLEAN_GFF" --outdir "$OUT" \
		--data "$DB_DIR" --cpu "${SLURM_CPUS_PER_TASK:-1}"
elif [[ $# -eq 2 ]]; then
	FNA=$1; OUT=$2
	[[ -s "$FNA" ]] || { echo "Error: '$FNA' missing or empty" >&2; exit 1; }
	echo "No GFF given: PADLOC will call genes itself with prodigal." >&2
	echo "Results will not be comparable with runs that used the bakta annotation." >&2
	mkdir -p "$OUT"
	padloc --fna "$FNA" --outdir "$OUT" \
		--data "$DB_DIR" --cpu "${SLURM_CPUS_PER_TASK:-1}"
else
	echo "$0 <faa> <gff3> <output directory>" >&2
	echo "$0 <fna> <output directory>" >&2
	exit 2
fi

echo "=== defence systems found ==="
csv=$(ls "$OUT"/*_padloc.csv 2>/dev/null | head -1)
if [[ -s "$csv" ]]; then
	awk -F',' 'NR>1{print $3}' "$csv" | sort | uniq -c | sort -rn
else
	echo "none"
fi
