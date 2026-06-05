#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=Slow5Stats
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o slow5stats-%j.out
#SBATCH -e slow5stats-%j.err

set -euo pipefail

SLOW5VER="1.4.0"
for BLOW in $(find Run1/blow5 -type f); do 
	 ~/scratch/slorado/slow5tools-v${SLOW5VER}/slow5tools stats stats $BLOW;
done

