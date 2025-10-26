#!/bin/bash
#SBATCH --job-name=checkm
#SBATCH --account=pawsey1018
#SBATCH --partition=highmem
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=720G
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

eval "$(conda shell.bash hook)"
conda  activate /scratch/pawsey1018/edwa0468/CF/crAss/MixedAssemblies/cross_assembly/checkm2/checkm2_env

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <FASTA directory> <output directory> <checkm2 exectuable>" >&2;
    exit 1
fi


if [[ ! -x "$3" ]]; then
    echo "Error: checkm2 executable '$3' not found or not executable." >&2;
    exit 1
fi

$3 predict --threads 32 --input $1 --output-directory $2 --database_path /home/edwa0468/Databases/checkm2/CheckM2_database/uniref100.KO.1.dmnd


