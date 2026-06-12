#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=Slow5Stats
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail

SLOW5VER="1.4.0"
for BLOW in $(find ./blow5 -type f); do 
	 /scratch/$PAWSEY_PROJECT/$USER/slorado/slow5tools-v${SLOW5VER}/slow5tools stats $BLOW;
done

