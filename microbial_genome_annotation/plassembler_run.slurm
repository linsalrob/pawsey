#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=plassembler
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err
#SBATCH --mem=64G

# Assemble plasmids from nanopore reads with plassembler
# https://github.com/gbouras13/plassembler
#
# Use this instead of autocycler_run.slurm when the sample is a plasmid prep
# rather than a whole bacterial isolate. Pass "none" as the third argument for
# plasmid-only reads, which runs plassembler with --no_chromosome.

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [[ $# -lt 2 || $# -gt 3 ]]; then
	echo "$0 <nanopore reads> <output directory> [chromosome length | none]" >&2
	echo >&2
	echo "  chromosome length: approximate lower bound for the chromosome, in bp" >&2
	echo "                     (default 1000000, the plassembler default)" >&2
	echo "  none:              the reads are plasmid only and no chromosome should" >&2
	echo "                     be expected, so run with --no_chromosome" >&2
	exit 2
fi

# location of the plassembler installation
CONDAENV=microbial_annotations
eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/$CONDAENV

# location of the PLASSEMBLER databases
export PLASSEMBLER_DB=$CONDA_PREFIX/plassembler/

reads=$1
output=$2
chromosome=${3:-1000000}

if [[ ! -f "$reads" ]]; then
	echo "Error: Input file '$reads' does not exist." >&2
	exit 1
fi

if [[ ! -s "$PLASSEMBLER_DB/plsdb_2023_11_03_v2.msh" ]]; then
	echo "Error: the PLSDB database is not installed in $PLASSEMBLER_DB." >&2
	echo "Run plassembler_install.slurm first." >&2
	exit 1
fi

threads=${SLURM_CPUS_PER_TASK:-1}

# --no_chromosome is a flag, not a value, so build the argument list rather than
# trying to pass an empty string (which set -u will not thank you for)
if [[ "$chromosome" == "none" || "$chromosome" == "no_chromosome" ]]; then
	echo "Running in plasmid-only mode (--no_chromosome)" >&2
	chromosome_args=(--no_chromosome)
else
	echo "Expecting a chromosome of at least $chromosome bp" >&2
	chromosome_args=(--chromosome "$chromosome")
fi

TMPDIR=$(mktemp -dp /scratch/$PAWSEY_ACCOUNT/$USER)
echo "Temporary files are being written to $TMPDIR" >&2

plassembler long \
	--database "$PLASSEMBLER_DB" \
	--longreads "$reads" \
	--outdir "$TMPDIR/plassembler_out" \
	--threads "$threads" \
	--force \
	--keep_chromosome \
	"${chromosome_args[@]}"

mkdir -p $(dirname "$output")
rsync -av $TMPDIR/ "$output"
rm -rf $TMPDIR

echo "plassembler results are in $output/plassembler_out"
