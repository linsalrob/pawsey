#!/bin/bash
#SBATCH --job-name=minimap
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o minimap-%j.out
#SBATCH -e minimap-%j.err

###################################################
#
# MAKE SURE YOU CREATE THIS ENVIRONMENT!
#
# mamba create -y --prefix=/scratch/$PAWSEY_ACCOUNT/$USER/software/miniconda3/minimap minimap2 samtools
#
#
###################################################

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

eval "$(conda shell.bash hook)"
conda activate /scratch/$PAWSEY_ACCOUNT/$USER/software/miniconda3/minimap


if [[ $# -ne 4 ]]; then echo "$0  <reference> <R1> <R2> <output>"; exit; fi

minimap2 -t 16 --split-prefix mmsplit$$ -ax sr $1 $2 $3  | samtools view -F 3584 -b --threads 16  | samtools sort -@ 16 -o $4 -

