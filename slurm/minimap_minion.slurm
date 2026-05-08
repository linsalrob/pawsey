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


if [[ $# -ne 3 ]]; then echo "$0  <reference> <sequences> <output>"; exit; fi


minimap2 -t 16 --split-prefix mmsplit$$ -ax map-ont $1 $2 | samtools view -F 3584 -b --threads 16  | samtools sort -@ 16 -o $3 -
