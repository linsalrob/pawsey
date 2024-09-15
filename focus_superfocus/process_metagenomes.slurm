#!/bin/bash
#SBATCH --job-name=metaf_sf
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH -o metaf_sf-%A_%a.out
#SBATCH -e metaf_sf-%A_%a.err

set -euo pipefail

if [[ $# -eq 0 ]]; then 
	echo "$0 <directory of sequence files>" >&2; 
	exit 1
fi


WD=$PWD

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm

DIR=$1

#for FQ in $(find $EPROJ/fasta -type f); do fastq2fasta $FQ ${FQ/fastq.gz/fasta} && rm -f $FQ; done

echo -e "\tRunning focus"
singularity exec --bind $PWD:/focus /home/edwa0468/Projects/focus/sif/focus_v1.8.0_d95c4fb1ae57.sif \
	focus -q /focus/$DIR -o /focus/focus -k 7 -t 16 

find focus -type f -exec gzip {} \;

echo -e "\tRunning superfocus"
singularity exec --bind $PWD/:/superfocus,/home/edwa0468/Projects/superfocus_db:/superfocus_db \
	 /home/edwa0468/Projects/superfocus/sif/superfocus_v1.6.0_b91c0c41d6a5.sif \
	superfocus -q /superfocus/$DIR -t 16 -dir /superfocus/superfocus -a mmseqs2 -db DB_95 -b /superfocus_db -d

find superfocus  -type f -exec gzip {} \;

