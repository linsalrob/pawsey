#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=mash
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o mash-%j.out
#SBATCH -e mash-%j.err

# set -euo pipefail
eval "$(conda shell.bash hook)"

############ README
#
#
# You can run this command eg. on deepthought by providing the name of a conda environment
#
# e.g. sbatch mash_reads.slurm mash
#
# Alternatively, we can create a tmp directory, but with pawsey you will run out of space 
# as an alternative you can create the tmp directory and provide is on the sbatch command
# 

if [[ $# == 0 ]]; then
	echo "Making tmp mash installation. You might want to reconsider this if you run several jobs"

	# Create a temporary environment to house mash and install it.
	TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done); TMP="mash_$TMP";

	echo "Creating mash in /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP"
	mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP python=3.12 mash
	conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

else
	conda activate $1
fi

FASTA="fasta"
MASH="mash"

mkdir -p $MASH

for F in $(find $FASTA  -type f -printf "%f\n" | perl -ne 'm/^(...\d+)/; print "$1\n"' | awk '!s[$0]++' | sort -R); do 
	if [[ ! -e $MASH/$F.msh ]]; then
		echo $F; 
		mash sketch -I $F -r -o $MASH/$F $FASTA/${F}*;
	fi
done

if [[ $# == 0 ]]; then
	rm -rf /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP
fi
