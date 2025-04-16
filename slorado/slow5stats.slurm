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

for BLOW in $(find Run1/blow5 -type f); do 
	/home/edwa0468/Projects/CF/Promethion/slow5tools-v1.3.0/slow5tools stats $BLOW;
done

