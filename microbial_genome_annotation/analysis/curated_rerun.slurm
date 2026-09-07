#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=curated_rerun
#SBATCH --partition=work
#SBATCH --time=08:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Rerun compress -> cluster -> trim -> resolve -> combine over a curated input
# set, then apply the same size-completeness gate as autocycler_run.slurm.
# Usage: curated_rerun.slurm <sample name>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

SAMPLE=$1
BASE=${PROJECT_DIR:-$PWD}
R=$BASE/${RESDIR:-rescue}/$SAMPLE
IN=$R/curated_assemblies
OUT=$R/curated_out
MAXCONTIGS=100

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/microbial_annotations

[[ -d "$IN" ]] || { echo "no curated input at $IN" >&2; exit 2; }
rm -rf "$OUT"

autocycler compress -i "$IN" -a "$OUT" --max_contigs $MAXCONTIGS
autocycler cluster  -a "$OUT" --max_contigs $MAXCONTIGS
for c in "$OUT"/clustering/qc_pass/cluster_*; do
	autocycler trim -c "$c"
	autocycler resolve -c "$c"
done
autocycler combine -a "$OUT" -i "$OUT"/clustering/qc_pass/cluster_*/5_final.gfa

# same gate as the main pipeline
genome_size=$(grep -oE -- "--genome_size [0-9]+" $BASE/logs/${GATELOG:-ac}_$SAMPLE-*.err | head -1 | grep -oE '[0-9]+')
MIN_RECOVERED_FRACTION=${MIN_RECOVERED_FRACTION:-0.75}
MAX_RECOVERED_FRACTION=${MAX_RECOVERED_FRACTION:-1.25}
assembled_bases=$(awk '/^consensus_assembly_bases:/ {print $2}' "$OUT/consensus_assembly.yaml")
fully_resolved=$(awk '/^consensus_assembly_fully_resolved:/ {print $2}' "$OUT/consensus_assembly.yaml")
cluster_count=$(grep -c '^- length:' "$OUT/consensus_assembly.yaml" || true)
recovered_fraction=$(awk -v a="$assembled_bases" -v g="$genome_size" 'BEGIN{printf "%.4f", (g>0?a/g:0)}')
gate=PASS; reason="-"
[[ "$fully_resolved" == "true" ]] || { gate=FAIL; reason="not fully resolved"; }
awk -v f="$recovered_fraction" -v lo="$MIN_RECOVERED_FRACTION" -v hi="$MAX_RECOVERED_FRACTION" \
	'BEGIN{exit !(f<lo || f>hi)}' && { gate=FAIL; reason="recovered fraction $recovered_fraction outside $MIN_RECOVERED_FRACTION-$MAX_RECOVERED_FRACTION"; }

{
printf "sample\testimated_genome_size\tassembled_bases\trecovered_fraction\tfully_resolved\tclusters\tgate\treason\tprovenance\n"
printf "sample%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
	"$SAMPLE" "$genome_size" "$assembled_bases" "$recovered_fraction" "$fully_resolved" \
	"$cluster_count" "$gate" "$reason" "manually curated Autocycler consensus"
} > "$R/curated_gate.tsv"
column -t -s$'\t' "$R/curated_gate.tsv"
echo "curated consensus: $OUT/consensus_assembly.fasta"
