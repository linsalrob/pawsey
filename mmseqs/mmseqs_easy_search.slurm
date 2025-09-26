#!/bin/bash
#SBATCH --job-name=mmseqs_search
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=300G
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 'echo "Error on line $LINENO: $BASH_COMMAND"' ERR

eval "$(conda shell.bash hook)"
conda activate bioinfie


MMSEQS=$(command -v mmseqs)

USAGE="${0} <fasta_file> <mmseqs_db_source_directory> <alignment output>";
if [ "$#" -ne 2 ]; then
    echo "Usage: $USAGE" >&2
    exit 1
fi

# Check mmseqs availability
if [ ! -x "$MMSEQS" ]; then
    echo "Error: mmseqs executable not found or not executable." >&2
    echo "Please provide the path to mmseqs or ensure it is in your PATH." >&2
    exit 1
fi


echo "Start " `date` >&2;

FAFILE=$1
if [[ ! -e $FAFILE ]]; then
	echo "Please provide a fasta file as the first argument" >&2;
	echo $USAGE >&2;
	exit 1;
fi

DBSOURCE=$2
if [[ ! -e $DBSOURCE ]]; then
	echo "Please provide a mmseqs database source directory as the second argument" >&2;
	echo $USAGE >&2;
	exit 1;
fi

ALIGNMENT=$3

TMP=$(mktemp -d -p /scratch/$PAWSEY_PROJECT/$USER/tmp)

echo "Running mmseqs easy-search $FAFILE $DBSOURCE $ALIGNMENT $TMP --threads 32" 2>&1;

$MMSEQS easy-search $FAFILE $DBSOURCE $ALIGNMENT $TMP --threads 32

echo "Fin " `date` >&2;

