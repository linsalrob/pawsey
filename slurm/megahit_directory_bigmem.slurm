#!/bin/bash
#SBATCH --job-name=MegaHitBig
#SBATCH --partition=highmem
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=960G
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# This will run megahit on all fastq.gz files in a given directory
# and requests max amount of memory on highmem partition.
# It assumes that files are named with _R1 and _R2 for paired-end reads
# and anything else is considered unpaired reads.
#
# It also assumes that the CONDA environment variable is set to the name of
# the conda environment where megahit is installed.
#
# Usage: sbatch --export CONDA=/scratch/pawsey1018/edwa0468/software/miniconda3/6d67963af33a megahit_directory_bigmem.slurm <directory of reads>
#
# Output will be in megahit_output directory.


echo "Started";

set -euo pipefail
# set -eu
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [[ ! -n "$CONDA" ]]; then
    echo "Please define the CONDA environment variable with the location of megahit">&2;
    exit 2;
fi

eval "$(conda shell.bash hook)"
conda activate $CONDA

if [[ $# != 1 ]]; then
    echo "Usage: $0 <directory of reads>" >&2
    exit 1
fi

echo "Working on $1";

if [[ ! -d "$1" ]]; then
    echo "$1 is not a directory" >&2
    exit 1
fi


# Collect R1 and R2 lists
R1_FILES=($(find $1 -name \*_R1.fastq.gz | sort))
R2_FILES=($(find $1 -name \*_R2.fastq.gz | sort))
OTHER_FILES=($(find $1 -name \*.fastq.gz | grep -v -E "_R[12]\.fastq\.gz" | sort)) || true

# Join them into comma-separated strings
R1_JOINED=$(IFS=,; echo "${R1_FILES[*]}")
R2_JOINED=$(IFS=,; echo "${R2_FILES[*]}")
OTHER_JOINED=$(IFS=,; echo "${OTHER_FILES[*]}")

echo -e "R1 files: ${R1_JOINED}\nR2 files: ${R2_JOINED}\nOthers: ${OTHER_JOINED}" >&2


# Build the final string

FINAL_STRING=""
if [[ ! -z  "${R1_JOINED}" ]]; then
    FINAL_STRING+="-1 ${R1_JOINED} "
fi
if [[ ! -z  "${R2_JOINED}" ]]; then
    FINAL_STRING+="-2 ${R2_JOINED} "
fi
if [[ ! -z  "${OTHER_JOINED}" ]]; then
    FINAL_STRING+="-r ${OTHER_JOINED} "
fi

echo "Running megahit with the following parameters: megahit $FINAL_STRING -o megahit_output" >&2

megahit $FINAL_STRING -o megahit_output 



