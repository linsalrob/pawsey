#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=defensefinder_install
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# DefenseFinder, for identifying antiviral defence systems in annotated genomes.
# https://github.com/mdmparis/defense-finder
#
# Installed into its own environment so that adding it cannot disturb a working
# assembly and annotation install. The MacSyFinder models are downloaded into
# ~/Databases/defensefinder rather than the default location under $HOME, so
# the models sit with the project's other reference data.

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONDAENV=defensefinder
ENV_DIR="/scratch/${PAWSEY_PROJECT}/${USER}/software/miniconda3/${CONDAENV}"
DB_DIR="$HOME/Databases/defensefinder"

eval "$(mamba shell hook --shell bash)"
if [[ -e "$ENV_DIR" || -L "$ENV_DIR" ]]; then
	echo "Removing existing $ENV_DIR"
	mamba env remove --yes --prefix "$ENV_DIR" || rm -rf -- "$ENV_DIR"
	rm -rf -- "$ENV_DIR"
fi

# hmmer and macsyfinder come from conda; defense-finder itself from PyPI
mamba create -y --prefix="$ENV_DIR" -c conda-forge -c bioconda \
	python=3.11 hmmer macsyfinder pip

mamba activate "$ENV_DIR"
python -m pip install --upgrade pip
python -m pip install mdmparis-defense-finder

defense-finder --version || true

mkdir -p "$DB_DIR"
echo "Downloading DefenseFinder models into $DB_DIR"
defense-finder update --models-dir "$DB_DIR"

echo "=== models ==="
ls "$DB_DIR" | head
du -sh "$DB_DIR"
echo "DefenseFinder installed in $ENV_DIR, models in $DB_DIR"
