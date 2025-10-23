#!/bin/bash
#SBATCH --job-name=gtdb
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

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <FASTA directory> <Database directory> <SIF Directory> " >&2;
    echo "Please make sure you use the full path to the directories." >&2;
    exit 1
fi

FADIR=$1
DBDIR=$2
SIFDIR=$3

if [[ ! -e $SIFDIR/gtdbtk_latest.sif ]]; then
	echo "GTDB-Tk SIF file (gtdbtk_latest.sif) not found in $SIFDIR" >&2
    exit 1
fi

module load singularity/3.11.4-slurm


singularity exec --bind $DBDIR:/refdata,$FADIR:/data $SIFDIR/gtdbtk_latest.sif \
    gtdbtk classify_wf --genome_dir /data --out_dir /data/gtdb --cpus 32 --extension fna




