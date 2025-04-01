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


usage() {
    echo "Usage: $0 [/path/to/mmseqs] R1_file R2_file" >&2
    echo "If /path/to/mmseqs is not provided, will look for 'mmseqs' in PATH." >&2
    exit 1
}

# Check number of arguments
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

# Handle argument parsing
if [ "$#" -eq 3 ]; then
    MMSEQS="$1"
    R1="$2"
    R2="$3"
else
    MMSEQS=$(command -v mmseqs)
    R1="$1"
    R2="$2"
fi

# Check mmseqs availability
if [ ! -x "$MMSEQS" ]; then
    echo "Error: mmseqs executable not found or not executable." >&2
    echo "Please provide the path to mmseqs or ensure it is in your PATH." >&2
    exit 1
fi

# Echo what's being used
echo "Using mmseqs: $MMSEQS"
echo "R1 file: $R1"
echo "R2 file: $R2"


echo "Start " `date` >&2;

DB=GTDB
DBSOURCE=/scratch/$PAWSEY_PROJECT/$USER/db/$DB

if [[ ! -e $DBSOURCE ]]; then
	echo "Please edit $0 and correct the location of the $DB files" >&2;
	exit 1;
fi

OUTDIR=mmseqs
mkdir -p $OUTDIR

OUTFILE=$(basename ${R1/.fasta.gz/})
OUTFILE=${OUTFILE/.fasta/}

OUTPUT=$OUTDIR/$OUTFILE.mmseqs.$DB

TMP=$(mktemp -d -p /scratch/$PAWSEY_PROJECT/$USER/tmp)

echo "Running mmseqs easy-taxonomy $R1 $R2 $DBSOURCE/$DB $OUTPUT $TMP --threads 32" 2>&1;


$MMSEQS easy-taxonomy $R1 $R2 $DBSOURCE/$DB $OUTPUT $TMP --threads 32

echo "Fin " `date` >&2;

