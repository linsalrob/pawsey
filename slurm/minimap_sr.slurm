#!/bin/bash
#SBATCH --job-name=minimap
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o minimap-%j.out
#SBATCH -e minimap-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate bioinformatics

if [[ $# -ne 4 ]]; then echo "$0  <reference> <R1> <R2> <output>"; exit; fi

minimap2 -t 16 -ax sr $1 $2 $3  | samtools view -F 3584 -b --threads 16  | samtools sort -@ 16 -o $4 -

