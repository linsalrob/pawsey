#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=padloc_install
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# PADLOC, for identifying antiviral defence systems in annotated genomes.
# https://github.com/padlocbio/padloc
#
# Installed into its own environment so that adding it cannot disturb a working
# assembly and annotation install. The HMM and system database is downloaded
# into ~/Databases/padloc rather than into the conda package directory, so that
# rebuilding the environment does not mean re-downloading the database.

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONDAENV=padloc
ENV_DIR="/scratch/${PAWSEY_PROJECT}/${USER}/software/miniconda3/${CONDAENV}"
DB_DIR="$HOME/Databases/padloc"

eval "$(mamba shell hook --shell bash)"
if [[ -e "$ENV_DIR" || -L "$ENV_DIR" ]]; then
	echo "Removing existing $ENV_DIR"
	mamba env remove --yes --prefix "$ENV_DIR" || rm -rf -- "$ENV_DIR"
	rm -rf -- "$ENV_DIR"
fi

mamba create -y --prefix="$ENV_DIR" -c conda-forge -c bioconda -c padlocbio padloc

mamba activate "$ENV_DIR"
padloc --version

# --db-update ignores --data and always installs into the package's own data
# directory, so download first, then relocate and symlink back. The symlink
# means a bare `padloc` with no --data still works, while the 950 MB database
# lives with the other reference data instead of inside the environment.
echo "Downloading the PADLOC database"
padloc --db-update

PKG_DATA="$ENV_DIR/data"
if [[ -d "$PKG_DATA" && ! -L "$PKG_DATA" ]]; then
	rm -rf -- "$DB_DIR"
	mkdir -p "$(dirname "$DB_DIR")"
	mv "$PKG_DATA" "$DB_DIR"
	ln -s "$DB_DIR" "$PKG_DATA"
	echo "Database relocated to $DB_DIR, symlinked from $PKG_DATA"
fi

echo "=== database contents ==="
ls "$DB_DIR" | head
du -sh "$DB_DIR"
echo "PADLOC installed in $ENV_DIR, database in $DB_DIR"
