#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=fastq_snapshot
#SBATCH --partition=work
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH -o logs/%x-%A_%a.out
#SBATCH -e logs/%x-%A_%a.err

# Per-sample read inventory, so reads arriving later can be diffed against a
# known baseline. Records file-level detail as well as totals, so a new chunk
# file is identifiable by name rather than only as a larger number.
#
# Usage: sbatch --array=1-N fastq_snapshot.slurm <samples file> <stamp> [reads subdir]
#
#   samples file  one sample name per line; the array task id selects the line
#   stamp         label for this snapshot, e.g. a timestamp
#   reads subdir  directory under PROJECT_DIR holding <sample>/*.fastq.gz
#                 (default: raw)
#
# Environment: PROJECT_DIR (default: current directory)

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

BASE=${PROJECT_DIR:-$PWD}
SAMPLES=$1
STAMP=$2
RAW=${3:-raw}

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES")
[[ -n "$SAMPLE" ]] || { echo "no sample on line $SLURM_ARRAY_TASK_ID of $SAMPLES" >&2; exit 2; }
D=$BASE/$RAW/$SAMPLE
OUT=$BASE/snapshots/$STAMP

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc
mkdir -p "$OUT/per_sample"

ls "$D"/*.fastq.gz 2>/dev/null | wc -l \
	| awk -v s="$SAMPLE" '{printf "%s\t%s\n", s, $1}' > "$OUT/per_sample/$SAMPLE.files.count"

# Keep the whole seqkit line rather than picking columns by index: -a emits
# num_seqs, sum_len, min/avg/max_len, Q1-Q3, sum_gap, N50, N50_num, Q20(%),
# Q30(%), AvgQual and GC(%), and choosing indices by eye gets them wrong.
cat "$D"/*.fastq.gz 2>/dev/null \
	| seqkit stats -T -a -j "${SLURM_CPUS_PER_TASK:-4}" - \
	| awk -v s="$SAMPLE" 'NR==1{print "sample\t"$0; next} {print s"\t"$0}' \
	> "$OUT/per_sample/$SAMPLE.seqstats.tsv"

for f in "$D"/*.fastq.gz; do stat -c "$SAMPLE	%n	%s	%y" "$f"; done \
	> "$OUT/per_sample/$SAMPLE.files.tsv"
du -sb "$D" | awk -v s="$SAMPLE" '{printf "%s\t%s\n", s, $1}' > "$OUT/per_sample/$SAMPLE.du.tsv"
echo "$SAMPLE done"
