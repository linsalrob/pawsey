#!/bin/bash --login
#SBATCH --account=pawsey1018
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=0-4
#SBATCH -o slow5extract-%j.out
#SBATCH -e slow5extract-%j.err

if [[ $# -eq 0 ]]; then 
	echo "$0 <slow5 file> <list of read ids> <output file>";
	exit 1;
fi


SLOW5TOOLS=/scratch/pawsey1018/edwa0468/slorado/slow5/slow5tools-v1.3.0/slow5tools

$SLOW5TOOLS get $1 --list $2 --output $3 -t 64
