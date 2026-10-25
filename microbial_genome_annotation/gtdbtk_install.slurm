#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=gtdbtk_install
#SBATCH --partition=work
#SBATCH --time=1-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# GTDB-Tk and its reference package, for taxonomy of metagenome-assembled genomes.
# https://github.com/Ecogenomics/GTDBTk
#
# The GTDB-Tk version and GTDB release must match: GTDB-Tk 2.7.x and 2.8.x read
# R232 only. Change both together.
#
# R232 unpacks to roughly 200,000 files (one skani genome per species cluster).
# /scratch has a 1,000,000 file per-user quota, so the extraction checks the
# free inode count first and refuses to start without MIN_SPARE_FILES left over.

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

GTDBTK_VERSION=2.8.0
RELEASE=232
URL="https://data.gtdb.ecogenomic.org/releases/release${RELEASE}/${RELEASE}.0/auxillary_files/gtdbtk_package/full_package/gtdbtk_r${RELEASE}_data.tar.gz"
MIN_SPARE_FILES=${MIN_SPARE_FILES:-100000}

CONDAENV=gtdbtk
ENV_DIR="/scratch/${PAWSEY_PROJECT}/${USER}/software/miniconda3/${CONDAENV}"
DB_ROOT="$HOME/Databases/GTDB"
DB_DIR="$DB_ROOT/release${RELEASE}"
TARBALL="$DB_ROOT/$(basename "$URL")"
# A shared, read-only copy of the release is used instead of downloading when it exists.
SHARED_DB="/scratch/references/gtdb_release${RELEASE}"

eval "$(mamba shell hook --shell bash)"
if [[ -e "$ENV_DIR" || -L "$ENV_DIR" ]]; then
	echo "Removing existing $ENV_DIR"
	mamba env remove --yes --prefix "$ENV_DIR" || rm -rf -- "$ENV_DIR"
	rm -rf -- "$ENV_DIR"
fi
mamba create -y --prefix="$ENV_DIR" -c conda-forge -c bioconda "gtdbtk=${GTDBTK_VERSION}"
mamba activate "$ENV_DIR"
gtdbtk --version

if [[ -s "$SHARED_DB/metadata/metadata.txt" ]]; then
	echo "Using the shared R${RELEASE} at $SHARED_DB; nothing to download"
	DB_DIR="$SHARED_DB"
else
mkdir -p "$DB_ROOT"
echo "Downloading $URL"
# -c resumes a partial download if the job is rerun
wget -c -q -O "$TARBALL" "$URL"
ls -l "$TARBALL"
md5sum "$TARBALL"

echo "Counting archive entries"
NFILES=$(pigz -dc -p "${SLURM_CPUS_PER_TASK:-4}" "$TARBALL" | tar -t | wc -l)
read -r USED LIMIT < <(lfs quota -u "$USER" /scratch | awk '$1=="/scratch" {gsub(/\*/,""); print $6, $8; exit}')
FREE=$((LIMIT - USED))
echo "archive entries: $NFILES; files used: $USED of $LIMIT; free: $FREE"
if (( FREE - NFILES < MIN_SPARE_FILES )); then
	echo "Error: extracting would leave fewer than $MIN_SPARE_FILES free files. Tarball kept at $TARBALL" >&2
	exit 2
fi

rm -rf -- "$DB_DIR"
mkdir -p "$DB_DIR"
pigz -dc -p "${SLURM_CPUS_PER_TASK:-4}" "$TARBALL" | tar -x -C "$DB_DIR" --strip-components=1
fi

mamba env config vars set --prefix "$ENV_DIR" GTDBTK_DATA_PATH="$DB_DIR"
mamba deactivate
mamba activate "$ENV_DIR"
echo "GTDBTK_DATA_PATH=$GTDBTK_DATA_PATH"
cat "$DB_DIR/metadata/metadata.txt" 2>/dev/null || true

gtdbtk check_install
echo "GTDB-Tk $GTDBTK_VERSION installed in $ENV_DIR, R${RELEASE} in $DB_DIR"
