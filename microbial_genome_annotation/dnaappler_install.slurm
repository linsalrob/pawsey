#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=dnaappler_install
#SBATCH --time=0-1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16GB
#SBATCH --ntasks=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

eval "$(conda shell.bash hook)"
TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP  dnaapler
echo -e "dnaappler installed in $TMP\n\nmamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP"



