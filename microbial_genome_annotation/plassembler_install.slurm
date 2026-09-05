#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=plassembler_install
#SBATCH --time=0-4
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# plassembler is already listed in autocycler.yaml, so it comes along with the
# microbial_annotations environment. This script is for the case where you only
# want plassembler, or where the PLSDB database needs (re)installing -- note that
# /scratch is purged, so the database does disappear from time to time.

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONDAENV=microbial_annotations
ENV_DIR="/scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/$CONDAENV"

eval "$(mamba shell hook --shell bash)"

if [[ ! -d "$ENV_DIR" ]]; then
	echo "Environment $ENV_DIR does not exist; creating it from autocycler.yaml" >&2
	mamba env create -y --prefix="$ENV_DIR" -f "$(dirname $0)/autocycler.yaml"
fi

mamba activate "$ENV_DIR"

if ! command -v plassembler > /dev/null; then
	echo "plassembler not found in $ENV_DIR, installing it" >&2
	mamba install --yes plassembler
fi

# same location that autocycler_run.slurm expects
export PLASSEMBLER_DB=$CONDA_PREFIX/plassembler/
echo "Installing the PLSDB database into $PLASSEMBLER_DB"
rm -rf "$PLASSEMBLER_DB"
plassembler download -d "$PLASSEMBLER_DB"

plassembler --version
echo "plassembler installed in $ENV_DIR"
echo "mamba activate $ENV_DIR"
