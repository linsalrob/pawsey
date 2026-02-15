#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=extract_genomes
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

for DIR in $(find /scratch/pawsey1018/gbouras/archaea/baktfold_compare_out/ -type f -size +1M); do
	GENOME=`basename $DIR .tar.gz`;
	GBFF=$(tar -ztf $DIR | grep $GENOME | grep gbff)
	if [[ $GENOME ]] &&  [[ $GBFF ]]; then
		tar -zxf $DIR $GBFF --to-stdout | gzip -c > genomes/$GENOME.gbff;
	else
		echo "Error extracting: tar -zxf $DIR $GBFF --to-stdout" >&2;
	fi
done

