#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=phispy
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# Identify prophages in an annotated genome with PhiSpy.
# https://github.com/linsalrob/PhiSpy
#
# Input is a GenBank file carrying gene calls -- the .gbff that bakta writes is
# exactly right. PhiSpy needs the annotation, not just the sequence, so run
# this after bakta rather than on an assembly.
#
# The third argument selects a training set. PhiSpy ships ~140 of them and
# recommends the most closely related one; `PhiSpy.py --list short` lists them.
# The default generic set is built from 48 genomes and is the right choice when
# nothing close is available, and the right choice when results must be
# comparable across genomes of different species. Passing an organism-specific
# set generally improves sensitivity for that organism at the cost of that
# comparability, so it is worth running both and reporting the difference.
#
# Usage: phispy_run.slurm <genbank file> <output directory> [training set]

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [[ $# -lt 2 || $# -gt 3 ]]; then
	echo "$0 <genbank file> <output directory> [training set]" >&2
	echo >&2
	echo "  training set: e.g. data/trainSet_Saureus.txt" >&2
	echo "                see 'PhiSpy.py --list short'" >&2
	exit 2
fi

GBK=$1
OUT=$2
TRAIN=${3:-}

[[ -s "$GBK" ]] || { echo "Error: '$GBK' does not exist or is empty" >&2; exit 1; }

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/phispy

train_args=()
if [[ -n "$TRAIN" ]]; then
	train_args=(--training_set "$TRAIN")
	echo "Using training set $TRAIN" >&2
else
	echo "Using PhiSpy's default generic training set" >&2
fi

mkdir -p "$OUT"

# output_choice is a bitmask; 512 writes everything, which is cheap here and
# saves rerunning when a downstream question needs a format that was skipped.
PhiSpy.py "$GBK" \
	--output_dir "$OUT" \
	--threads "${SLURM_CPUS_PER_TASK:-2}" \
	--output_choice 512 \
	--include_all_repeats \
	"${train_args[@]}"

echo "=== prophages found ==="
if [[ -s "$OUT/prophage_coordinates.tsv" ]]; then
	wc -l < "$OUT/prophage_coordinates.tsv" | xargs echo "regions:"
	cat "$OUT/prophage_coordinates.tsv"
else
	echo "none"
fi
