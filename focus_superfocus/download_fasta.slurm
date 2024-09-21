#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=download
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=12GB
#SBATCH -o download-%A_%a.out
#SBATCH -e download-%A_%a.err


SRR=$(head -n $SLURM_ARRAY_TASK_ID run_ids.txt | tail -n 1)

# if you don't have the sra toolkit you can download the latest url from
# https://github.com/ncbi/sra-tools/wiki/01.-Downloading-SRA-Toolkit # sratoolkit 

/home/edwa0468/Projects/laura/more_data/sratoolkit.3.1.1-ubuntu64/bin/fasterq-dump --split-3 $SRR --outdir fasta --fasta-unsorted
