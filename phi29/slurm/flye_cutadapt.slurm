#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=flye
#SBATCH --time=0-2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=128G
#SBATCH -o flyec-%j.out
#SBATCH -e flyec-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
# TMP is a temp conda environment with spades installed
TMP=6661a912bbf4
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP


FQDIR="cutadapt_to_assemble"
ODIR="cutadapt_assembled"
mkdir -p $ODIR

fq=$1
base=$(basename "${fq}" .fastq)
if [[ -e $ODIR/$base ]]; then 
	continue
fi
echo "Assembling $FQDIR/$fq into $ODIR/$base"
flye  --nano-raw $FQDIR/$fq --out-dir $ODIR/$base -t 64 --keep-haplotypes
