#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=count_fasta
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=12GB
#SBATCH -o count_fasta-%j.out
#SBATCH -e count_fasta-%j.err

if [[ $# == 0 ]]; then
	echo "$0 <directory of fasta files" >&2;
	exit 1;
fi

echo "Counting fasta files in $1"

/home/edwa0468/bin/count_fasta -d $1

