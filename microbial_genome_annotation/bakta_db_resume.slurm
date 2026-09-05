#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --partition=copy
#SBATCH --job-name=bakta_db_resume
#SBATCH --time=2-00:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 'status=$?; echo "$0: Error on line $LINENO: $BASH_COMMAND" >&2; exit "$status"' ERR

ENV_DIR=/scratch/pawsey1018/edwa0468/software/miniconda3/microbial_annotations
DB_ROOT=/scratch/pawsey1018/edwa0468/Databases/bakta
DB_TARBALL="$DB_ROOT/db.tar.xz"
DB_RECORD=14916843
DB_URL="https://zenodo.org/record/${DB_RECORD}/files/db.tar.xz"
VERSIONS_URL=https://raw.githubusercontent.com/oschwengers/bakta/main/db-versions.json

export PATH="$ENV_DIR/bin:$PATH"

mkdir -p "$DB_ROOT"

echo "Resuming Bakta database download at $(date -Is)"
echo "Existing bytes: $(stat -c %s "$DB_TARBALL" 2>/dev/null || echo 0)"
wget --continue --output-document="$DB_TARBALL" "$DB_URL"

echo "Validating XZ stream"
xz --test "$DB_TARBALL"

echo "Validating MD5 against the official Bakta database manifest"
expected_md5=$(
    "$ENV_DIR/bin/python" -c \
        'import json, sys, urllib.request; versions=json.load(urllib.request.urlopen(sys.argv[1])); print(next(v["md5"] for v in versions if str(v["record"]) == sys.argv[2]))' \
        "$VERSIONS_URL" "$DB_RECORD"
)
actual_md5=$(md5sum "$DB_TARBALL" | awk '{print $1}')
if [[ "$actual_md5" != "$expected_md5" ]]; then
    echo "MD5 mismatch: expected $expected_md5, observed $actual_md5" >&2
    exit 1
fi

echo "Installing and validating the Bakta database"
"$ENV_DIR/bin/bakta_db" install --db-file "$DB_TARBALL" --output "$DB_ROOT"
test -s "$DB_ROOT/db/version.json"
echo "Bakta database recovery completed at $(date -Is)"
