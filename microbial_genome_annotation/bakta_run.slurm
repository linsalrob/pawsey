#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=bakta
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [[ $# -ne 2 ]]; then
	echo "$0 <input fasta file> <output directory>" >&2;
	exit 1;
fi



eval "$(mamba shell hook --shell bash)"
TMP=f95d9fdce5b0
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

BAKTA_DB=/scratch/pawsey1018/edwa0468/Databases/bakta/db
bakta --keep-contig-headers --db $BAKTA_DB --output $2 $1

