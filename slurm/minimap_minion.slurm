#!/bin/bash
#SBATCH --job-name=minimap
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64GB
#SBATCH -o minimap-%j.out
#SBATCH -e minimap-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate bioinformatics

if [[ $# -ne 3 ]]; then echo "$0  <reference> <sequences> <output>"; exit; fi


minimap2 -t 16 -ax map-ont $1 $2 | samtools view -F 3584 -b --threads 16  | samtools sort -@ 16 -o $3 -
