#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=autocycler_install
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
mamba env create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP -f  autocycler.yaml
echo -e "autocycler installed in $TMP\n\nmamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP"
echo "Installing databases"
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

export PLASSEMBLER_DB=$HOME/Databases/plassembler/
rm -rf $PLASSEMBLER_DB
plassembler download -d $PLASSEMBLER_DB

