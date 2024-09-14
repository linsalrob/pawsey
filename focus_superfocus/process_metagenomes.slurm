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

WD=$PWD

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm

eval "$(conda shell.bash hook)"
conda activate rclone

for EPROJ in $(rclone lsd PhablesMGNify:General/data/fastq/ | awk '{print $NF}'); do
	for EANAL in $(rclone lsd PhablesMGNify:General/data/fastq/$EPROJ | awk '{print $NF}'); do
		echo "Analysing $EPROJ : $EANAL";

		mkdir fasta
		rclone copy PhablesMGNify:General/data/fastq/$EPROJ/$EANAL/ fasta
		for FQ in $(find fasta -type f); do fastq2fasta $FQ ${FQ/fastq.gz/fasta} && rm -f $FQ; done
		
		echo -e "\tRunning focus"
		singularity exec --bind $PWD:/focus /home/edwa0468/Projects/focus/sif/focus_v1.8.0_d95c4fb1ae57.sif \
			focus -q /focus/fasta -o /focus/${EANAL}_focus -k 7 -t 16 -p $EANAL

		find ${EANAL}_focus -type f -exec gzip {} \;

		echo -e "\tRunning superfocus"
		singularity exec --bind $PWD/:/superfocus,/home/edwa0468/Projects/superfocus_db:/superfocus_db \
			/home/edwa0468/Projects/superfocus/sif/superfocus_v1.6.0_5abbef95a6ca.sif \
			superfocus", "-q /superfocus/fasta -t 16 -dir /superfocus/${EANAL}_superfocus -a mmseqs2 -db DB_95 -b /superfocus_db -d -o $EANAL

		find ${EANAL}_superfocus  -type f -exec gzip {} \;
		rm -rf fasta 
	done
done

