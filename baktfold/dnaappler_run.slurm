#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=dnaappler
#SBATCH --time=0-1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32GB
#SBATCH --ntasks=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

eval "$(mamba shell hook --shell bash)"
TMP=d9ebf2f973b8
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP


if [[ $# -eq 3 ]]; then
    dnaapler all -i $1 -o $2 -p $3 -t 8
elif [[ $# -eq 2 ]]; then 
    dnaapler all -i $1 -o $2 -t 8
else
    echo "$0 <contigs file> <output file> <optional bacterial name>" >&2;
    exit 1
fi
