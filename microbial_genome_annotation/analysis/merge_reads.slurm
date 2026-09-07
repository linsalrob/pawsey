#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=merge_reads
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH -o logs/%x-%A_%a.out
#SBATCH -e logs/%x-%A_%a.err

# Merge a sample's chunked reads into one file. Basecallers emit many small
# gzipped chunks; gzip members concatenate, so plain cat is lossless.
#
# If a second source directory is given it is treated as the newer one, and the
# job first checks whether it CONTAINS the older. A directory of newly arrived
# reads is frequently a re-export that includes everything already held, and
# concatenating the two would duplicate every original read: that corrupts
# genome-size estimation, breaks subsampling, doubles apparent depth and gives
# duplicated positions false support. Where the newer contains the older, only
# the newer is used. Where it does not, the job refuses rather than guessing.
#
# Usage: sbatch --array=1-N merge_reads.slurm <samples file> <dir> [newer dir]
#
# Environment: PROJECT_DIR (default: current directory)
#              OUTDIR      (default: reads)

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

BASE=${PROJECT_DIR:-$PWD}
SAMPLES=$1
DIR1=$2
DIR2=${3:-}
OUTDIR=${OUTDIR:-reads}

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES")
[[ -n "$SAMPLE" ]] || { echo "no sample on line $SLURM_ARRAY_TASK_ID" >&2; exit 2; }
mkdir -p "$BASE/$OUTDIR"
OUT=$BASE/$OUTDIR/$SAMPLE.fastq.gz

SRC=$BASE/$DIR1/$SAMPLE
if [[ -n "$DIR2" ]]; then
	OLD=$BASE/$DIR1/$SAMPLE
	NEW=$BASE/$DIR2/$SAMPLE
	missing=0
	for f in "$OLD"/*.fastq.gz; do
		[[ -e "$f" ]] || continue
		n="$NEW/$(basename "$f")"
		if [[ ! -f "$n" ]] || [[ "$(stat -c %s "$f")" != "$(stat -c %s "$n")" ]]; then
			echo "NOT CONTAINED: $(basename "$f")" >&2; missing=$((missing+1))
		fi
	done
	if (( missing > 0 )); then
		echo "$SAMPLE: $missing file(s) of $DIR1 absent or differing in $DIR2." >&2
		echo "These are not the same data re-exported. Merging them here would" >&2
		echo "risk duplicating reads; decide explicitly how to combine them." >&2
		exit 4
	fi
	echo "$SAMPLE: $DIR1 is fully contained in $DIR2; using $DIR2 alone"
	SRC=$NEW
fi

cat "$SRC"/*.fastq.gz > "$OUT"
echo "$SAMPLE -> $OUT ($(stat -c %s "$OUT") bytes)"
