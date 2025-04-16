#!/bin/bash
#SBATCH --job-name=bluecrab
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128GB
#SBATCH -o bluecrab-%j.out
#SBATCH -e bluecrab-%j.err

set -euo pipefail

source /scratch/$PAWSEY_PROJECT/$USER/slorado/blue-crab-venv/bin/activate

BASE=.

blue-crab p2s --out-dir $BASE/blow5/ --compress zlib --threads 16 $BASE/pod5
