#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=phispy_install
#SBATCH --partition=work
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# PhiSpy, for identifying prophages in annotated bacterial genomes.
# https://github.com/linsalrob/PhiSpy
#
# Installed into its own environment rather than into microbial_annotations, so
# that adding it cannot disturb a working assembly and annotation install.

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONDAENV=phispy
ENV_DIR="/scratch/${PAWSEY_PROJECT}/${USER}/software/miniconda3/${CONDAENV}"

eval "$(mamba shell hook --shell bash)"
if [[ -e "$ENV_DIR" || -L "$ENV_DIR" ]]; then
	echo "Removing existing $ENV_DIR"
	mamba env remove --yes --prefix "$ENV_DIR" || rm -rf -- "$ENV_DIR"
	rm -rf -- "$ENV_DIR"
fi

mamba create -y --prefix="$ENV_DIR" -c conda-forge -c bioconda phispy

mamba activate "$ENV_DIR"
PhiSpy.py --version
echo "PhiSpy installed in $ENV_DIR"
echo "training sets available:"
PhiSpy.py --list short 2>&1 | head -20 || true
