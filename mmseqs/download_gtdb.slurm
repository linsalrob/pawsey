#!/bin/bash
#SBATCH --job-name=MMSeqsDld
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --partition=copy
#SBATCH --mem=64G
#SBATCH -o mmseqsdld-%j.out
#SBATCH -e mmseqsdld-%j.err

# Use `mmseqs databases` to find information about the preformatted databases
# NOTE: Do not download the NT database unless you _really_ need it. The database is huge!

if ! command -v mmseqs &> /dev/null; then
    echo "mmseqs not found in PATH. Checking to see if you provided it" >&2

    # Check if user provided an argument
    if [ -n "$1" ]; then
        if [ -x "$1" ]; then
            echo "Using mmseqs from: $1"
            MMSEQS="$1"
        else
            echo "Error: '$1' is not a valid mmseqs executable." >&2
            exit 1
        fi
    else
        echo -e "Please provide a path to mmseqs\nUsage: $0 /path/to/mmseqs" >&2
        exit 1
    fi
else
    MMSEQS=$(command -v mmseqs)
    echo "Found mmseqs at: $MMSEQS"
fi




DESTINATION=/scratch/$PAWSEY_PROJECT/$USER/db/
TMP=/scratch/$PAWSEY_PROJECT/$USER/tmp
mkdir -p $DESTINATION $TMP

#for DB in UniRef50 UniRef100; do

DB=GTDB
TPD=$(mktemp -d -p $TMP)
echo "Downloading to $DESTINATION/$DB and using temp location $TPD" >&2
$MMSEQS databases --threads 8 $DB $DESTINATION/$DB $TPD



