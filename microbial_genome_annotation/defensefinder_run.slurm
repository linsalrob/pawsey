#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=defensefinder
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# Identify antiviral defence systems with DefenseFinder.
# https://github.com/mdmparis/defense-finder
#
# Input is a protein FASTA; bakta's .faa is the right file. Pass --preserve-raw
# so the underlying MacSyFinder output is kept, since the summary tables alone
# do not say which protein matched which model.
#
# DefenseFinder needs to know gene order to call multi-gene systems. It infers
# that from the order of records in the FASTA, so the .faa must not be sorted
# or shuffled -- bakta writes it in coordinate order, which is what is wanted.
#
# Usage: defensefinder_run.slurm <protein fasta> <output directory>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [[ $# -ne 2 ]]; then
	echo "$0 <protein fasta> <output directory>" >&2
	exit 2
fi

FAA=$1
OUT=$2
[[ -s "$FAA" ]] || { echo "Error: '$FAA' missing or empty" >&2; exit 1; }

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/defensefinder
DB_DIR="$HOME/Databases/defensefinder"

[[ -d "$DB_DIR" ]] || { echo "Error: models missing at $DB_DIR; run defensefinder_install.slurm" >&2; exit 1; }

mkdir -p "$OUT"
defense-finder run \
	--models-dir "$DB_DIR" \
	--out-dir "$OUT" \
	--workers "${SLURM_CPUS_PER_TASK:-1}" \
	--preserve-raw \
	"$FAA"

echo "=== defence systems found ==="
sys=$(ls "$OUT"/*defense_finder_systems.tsv 2>/dev/null | head -1)
if [[ -s "$sys" ]]; then
	awk -F'\t' 'NR>1{print $2}' "$sys" | sort | uniq -c | sort -rn
else
	echo "none"
fi
