#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=checkm2_install
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# CheckM2, for completeness and contamination of metagenome-assembled genomes.
# https://github.com/chklovski/CheckM2
#
# Installed into its own environment. The DIAMOND database is downloaded into
# ~/Databases/checkm2 rather than the default under $HOME/databases, so it sits
# with the other reference data and survives rebuilding the environment.
#
# A shared copy of the same database (v3, md5 4db58455c51ff15804b6b8e19ff99f58)
# is at /scratch/references/VEBA-DB_v9/Classify/CheckM2/uniref100.KO.1.dmnd;
# see the README for pointing the environment at it instead of downloading.

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONDAENV=checkm2
ENV_DIR="/scratch/${PAWSEY_PROJECT}/${USER}/software/miniconda3/${CONDAENV}"
DB_DIR="$HOME/Databases/checkm2"

eval "$(mamba shell hook --shell bash)"
if [[ -e "$ENV_DIR" || -L "$ENV_DIR" ]]; then
	echo "Removing existing $ENV_DIR"
	mamba env remove --yes --prefix "$ENV_DIR" || rm -rf -- "$ENV_DIR"
	rm -rf -- "$ENV_DIR"
fi

mamba create -y --prefix="$ENV_DIR" -c conda-forge -c bioconda "checkm2>=1.1.0"

mamba activate "$ENV_DIR"
checkm2 --version

mkdir -p "$DB_DIR"
echo "Downloading the CheckM2 database into $DB_DIR"
checkm2 database --download --path "$DB_DIR"

DMND=$(find "$DB_DIR" -name '*.dmnd' | head -n 1)
[[ -s "$DMND" ]] || { echo "Error: no .dmnd found under $DB_DIR" >&2; exit 1; }
ls -l "$DMND"
md5sum "$DMND"

# Point the environment at the database so the run scripts need no extra flag
mamba env config vars set --prefix "$ENV_DIR" CHECKM2DB="$DMND"

checkm2 testrun --database_path "$DMND" --threads "${SLURM_CPUS_PER_TASK:-1}"
echo "CheckM2 installed in $ENV_DIR, database $DMND"
