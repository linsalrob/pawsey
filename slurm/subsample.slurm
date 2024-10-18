#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=subsample
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32GB
#SBATCH -o subsample-%j.out
#SBATCH -e subsample-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate bioinfie
source ~/GitHubs/EdwardsLab/venv/bin/activate



for R1 in $(find fasta -type f -printf "%f\n"); do 
	if [[ $R1 == *"_R2"* ]]; then
		continue
	fi
	R2=${R1/_R1/_R2};
	if [[ ! -e fasta_subsampled/$R1 ]]; then
		if [[ $R1 != $R2 ]] && [[ -e fasta/$R2 ]]; then 
			echo "R1=$R1; R2=$R2" >&2; 
			python ~/GitHubs/EdwardsLab/fasta/reservoir_sample_fasta.py --fasta fasta/$R1 --reverse fasta/$R2 --output fasta_subsampled/$R1 --reverse_output fasta_subsampled/$R2;
		else 
			echo "R1=$R1" >&2;
			python ~/GitHubs/EdwardsLab/fasta/reservoir_sample_fasta.py --fasta fasta/$R1 --output fasta_subsampled/$R1
		fi;
	fi;
done
