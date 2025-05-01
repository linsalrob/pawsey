#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=checkv
#SBATCH --time=0-5
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64G
#SBATCH -o checkv-%j.out
#SBATCH -e checkv-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/checkv

BASE="assembled"

export CHECKVDB=/home/edwa0468/Databases/checkv/checkv-db-v1.5


for ASS in $(find $BASE -type f -name assembly.fasta); do
	OUTDIR=$(dirname $ASS)
	OUTDIR="$OUTDIR/checkv"
	if [[ -e $OUTDIR ]]; then continue; fi
	echo "Running checkv on $ASS and putting results in $OUTDIR"
	checkv end_to_end  $ASS $OUTDIR -t 64
done
