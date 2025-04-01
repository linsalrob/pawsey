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

# Check if user provided an argument
if [ -n "$1" ]; then
	if [ -x "$1" ]; then
		echo "Using mmseqs from: $1"
		MMSEQS="$1"
	fi
elif command -v mmseqs &> /dev/null; then
	MMSEQS=$(command -v mmseqs)
	echo "Found mmseqs at: $MMSEQS"
else
	echo -e "Please provide a path to mmseqs\nUsage: $0 /path/to/mmseqs" >&2
	exit 1
fi


DESTINATION=/scratch/$PAWSEY_PROJECT/$USER/db
TMP=/scratch/$PAWSEY_PROJECT/$USER/tmp
mkdir -p $DESTINATION $TMP

#DB can also be  UniRef50 UniRef100 etc

DB=GTDB
TPD=$(mktemp -d -p $TMP)
echo -e "Downloading to $DESTINATION/$DB and using temp location $TPD.\nNote we download the tarball and then uncompress, so there is usually nothing in the output for a while!" >&2
$MMSEQS databases --threads 8 $DB $DESTINATION/$DB $TPD



