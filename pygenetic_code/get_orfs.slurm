#!/bin/bash
#SBATCH --job-name=translating
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=32GB
#SBATCH -o translating-%j.out
#SBATCH -e translating-%j.err

set -euo pipefail

if [[ $# -ne 2 ]]; then
	echo "$0 <fast[aq] file> <output file>" >&2
fi

~/GitHubs/get_orfs/bin/get_orfs -f $1 -l 20 -j 32 > $2
