#!/bin/bash
#SBATCH --job-name=tms_metaf_sf
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH -o tms_metaf_sf-%j.out
#SBATCH -e tms_metaf_sf-%j.err

set -euo pipefail

WD=$PWD

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm

eval "$(conda shell.bash hook)"
conda activate rclone

for EPROJ in $(rclone lsd PhablesMGNify:General/data/fastq_dereplicated/ | awk '{print $NF}'); do
	if [ ! -e ${EPROJ} ]; then
		mkdir -p $EPROJ/fasta
		rclone copy PhablesMGNify:General/data/fastq_dereplicated/$EPROJ $EPROJ/fasta
		for FQ in $(find $EPROJ/fasta -type f); do fastq2fasta $FQ ${FQ/fastq.gz/fasta} && rm -f $FQ; done
		
		echo -e "\tRunning focus"
		singularity exec --bind $PWD:/focus /home/edwa0468/Projects/focus/sif/focus_v1.8.0_d95c4fb1ae57.sif \
			focus -q /focus/$EPROJ/fasta -o /focus/$EPROJ/${EPROJ}_focus -k 7 -t 16 -p $EPROJ

		find $EPROJ/${EPROJ}_focus -type f -exec gzip {} \;

		echo -e "\tRunning superfocus"
		singularity exec --bind $PWD/:/superfocus,/home/edwa0468/Projects/superfocus_db:/superfocus_db \
			/home/edwa0468/Projects/superfocus/sif/superfocus_v1.6.0_b91c0c41d6a5.sif \
			superfocus -q /superfocus/$EPROJ/fasta -t 16 -dir /superfocus/$EPROJ/${EPROJ}_superfocus -a mmseqs2 -db DB_95 -b /superfocus_db -d -o $EPROJ

		find $EPROJ/${EPROJ}_superfocus  -type f -exec gzip {} \;
		rm -rf $EPROJ/fasta 
	fi 
done

