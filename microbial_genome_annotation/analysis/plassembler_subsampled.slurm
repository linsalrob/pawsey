#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=pl2_subsampled
#SBATCH --partition=work
#SBATCH --time=08:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Round-2 plassembler on subsampled reads.
#
# --no_chromosome sends every read into the plasmid pool, so the whole library
# reaches canu and Unicycler/SPAdes. On the round-1 sample17 library (4.7 Gbp)
# that ran for 19 h without finishing and canu failed to correct anything; the
# same data subsampled to 200 Mbp finished in 23 min with canu succeeding. The
# round-2 libraries are roughly twice as large again, so subsampling is not
# optional here.
#
# 200 Mbp is still tens of thousands of fold coverage for a few-kb plasmid.
#
# Usage: plassembler_subsampled.slurm <sample> <target Mbp> [seed]

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

SAMPLE=$1
TARGET_MBP=${2:-200}
SEED=${3:-42}
BASE=${PROJECT_DIR:-$PWD}
READS=$BASE/${READDIR:-reads}/$SAMPLE.fastq.gz
SUB=$BASE/${READDIR:-reads}/$SAMPLE_sub${TARGET_MBP}Mbp.fastq.gz
OUT=$BASE/${PLASDIR:-plasmids}/$SAMPLE
THREADS=${SLURM_CPUS_PER_TASK:-8}

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc

if [[ ! -s "$SUB" ]]; then
	total=$(seqkit stats -T "$READS" | awk 'NR==2{print $5}')
	frac=$(awk -v t="$total" -v m="$TARGET_MBP" 'BEGIN{f=m*1e6/t; if(f>1)f=1; printf "%.6f", f}')
	echo "$SAMPLE: total $total bases; fraction $frac for ~${TARGET_MBP} Mbp (seed $SEED)"
	seqkit sample -p "$frac" -s "$SEED" -o "$SUB" "$READS"
fi
seqkit stats -T -a "$SUB"

mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/microbial_annotations
export PLASSEMBLER_DB=$CONDA_PREFIX/plassembler/
TMPD=$(mktemp -dp /scratch/$PAWSEY_ACCOUNT/$USER)
echo "temp: $TMPD"

plassembler long --database "$PLASSEMBLER_DB" --longreads "$SUB" \
	--outdir "$TMPD/plassembler_out" --threads "$THREADS" --force \
	--keep_chromosome --no_chromosome --chromosome 1000000

mkdir -p "$(dirname "$OUT")"
rsync -a "$TMPD"/ "$OUT"
rm -rf "$TMPD"
echo "=== plasmids ==="
grep '^>' "$OUT/plassembler_out/plassembler_plasmids.fasta" || echo "(none)"
