#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=bakta
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [[ $# -ne 2 ]]; then
	echo "$0 <input fasta file> <output directory>" >&2;
	exit 1;
fi



eval "$(mamba shell hook --shell bash)"
CONDAENV=microbial_annotations
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$CONDAENV

BAKTA_DB=/scratch/pawsey1018/edwa0468/Databases/bakta/db

# bakta defaults to a single thread, which is hours per genome. Derive the
# thread count from the allocation, the same way autocycler_run.slurm does.
bakta --keep-contig-headers --db $BAKTA_DB --threads ${SLURM_CPUS_PER_TASK:-1} \
	--output $2 $1

