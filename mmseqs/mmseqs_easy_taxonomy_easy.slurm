#!/bin/bash

###############################################################
#                                                             #
# mmseqs easy taxonomy against UniRef50                       #
#                                                             #
# Note that you need a fasta file                             #
# Also make sure that the reads are labeled /1 /2             #
# (without a space)                                           #
#                                                             #
#                                                             #
###############################################################


#SBATCH --job-name=mmseqsET
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=200G
#SBATCH -o mmseqsET-%j.out
#SBATCH -e mmseqsET-%j.err

set -euo pipefail

usage() {
	echo "Usage: $0 [/path/to/mmseqs] fasta_file [outputdir]" >&2
	exit 1
}

if [[ $# -eq 0 ]]; then
	usage
fi

# check if $1 is the path to an mmseqs executable
if [ -n "$1" ] && [ -x "$1" ]; then
	MMSEQS="$1"
	shift
elif [ -x "$(command -v mmseqs)" ]; then
	MMSEQS=$(command -v mmseqs)
fi
if [ -z "$MMSEQS" ]; then
	echo "Error: mmseqs executable not found or not executable." >&2
	echo "Please provide the path to mmseqs or ensure it is in your PATH." >&2
	exit 1
fi


# Echo what's being used
echo "Sequence file: $1"


echo "Start " `date` >&2;

DB=UniRef50
DBSOURCE=/scratch/$PAWSEY_PROJECT/$USER/Databases/$DB

if [[ ! -e $DBSOURCE ]]; then
	echo "Please edit $0 and correct the location of the $DB files" >&2;
	exit 1;
fi

if [[ -n $2 ]]; then
	OUTDIR=$2
else
	OUTDIR=mmseqs
fi

mkdir -p $OUTDIR

OUTFILE=$(basename ${1/.fasta.gz/})
OUTFILE=${OUTFILE/.fasta/}
OUTFILE=${OUTFILE/R1./}

OUTPUT=$OUTDIR/$OUTFILE.mmseqs.$DB

TMP=$(mktemp -d -p /scratch/$PAWSEY_PROJECT/$USER/tmp)

echo "Running $MMSEQS easy-taxonomy $1 $DBSOURCE/$DB $OUTPUT $TMP --threads 32" 2>&1;


$MMSEQS easy-taxonomy $1 $DBSOURCE/$DB $OUTPUT $TMP --threads 32

echo "Fin " `date` >&2;

