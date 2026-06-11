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
#TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
CONDAENV=autocycler
mamba env create -y --prefix=/scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/$CONDAENV -f  autocycler.yaml
echo -e "autocycler installed in $CONDAENV\n\nmamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/$CONDAENV"

mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/$CONDAENV
export PLASSEMBLER_DB=$CONDA_PREFIX/plassembler/
echo "Installing the databases into $PLASSEMBLER_DB"
rm -rf $PLASSEMBLER_DB
plassembler download -d $PLASSEMBLER_DB

