#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=bakta_install
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

eval "$(mamba shell hook --shell bash)"
TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP  bakta
echo -e "bakta installed in $TMP\n\nmamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP"
echo "Installing databases"
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

bakta_db download --output ~/Databases/bakta

