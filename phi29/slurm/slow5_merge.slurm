#!/bin/bash --login
#SBATCH --account=pawsey1018
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=0-4
#SBATCH --mem=220G
#SBATCH -o slow5merge-%j.out
#SBATCH -e slow5merge-%j.err


SLOW5TOOLS=/scratch/pawsey1018/edwa0468/slorado/slow5/slow5tools-v1.3.0/slow5tools

$SLOW5TOOLS merge blow5 -o signals.blow5 -t64
$SLOW5TOOLS index signals.blow5
