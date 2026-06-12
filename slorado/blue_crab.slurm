#!/bin/bash
#SBATCH --job-name=bluecrab
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=128GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail

source /scratch/$PAWSEY_PROJECT/$USER/slorado/blue-crab-venv/bin/activate

BASE=.

blue-crab -v p2s --out-dir $BASE/blow5/ --compress zlib --threads $SLURM_CPUS_PER_TASK $BASE/pod5
