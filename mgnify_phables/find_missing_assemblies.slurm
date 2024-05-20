#!/bin/bash
#SBATCH --job-name=FindMissing
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH -o missing_assemblies-%j.out
#SBATCH -e missing_assemblies-%j.err

for GFA_PATH in $(cat $1); do 
	ACC=`basename $GFA_PATH .gfa.gz`
	PROJECT=$(basename $(dirname $GFA_PATH))
	python ~/GitHubs/pawsey/mgnify_phables/bioproject_accession_to_fastq.py -p $PROJECT -a $ACC
done
