#!/bin/bash
#SBATCH --job-name=ssra_sf_f
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH -o ssra_metaf_sf-%j.out
#SBATCH -e ssra_metaf_sf-%j.err

set -euo pipefail


module load pawseyenv/2023.08
module load singularity/3.11.4-slurm

# we have the SearchSRA metagenomes on Acacia
# and they are organised as 
# A18:searchsra/fasta/20201013/
# 	DRR
# 	ERR
# 	SRR
#
# We will create a directory for each DRR (e.g. DRR025) and then run focus and superfocus on that
# and then delete the fasta

eval "$(conda shell.bash hook)"
conda activate rclone

WD=$PWD
for SRA in DRR ERR SRR; do 
	mkdir -p $SRA
	cd $SRA
	for EPROJ in $(rclone lsd A18:searchsra/fasta/20201013/DRR | awk '{print $NF}'); do
		if [ ! -e ${EPROJ} ]; then
			mkdir -p $EPROJ/fasta
			rclone copy A18:searchsra/fasta/20201013/DRR/$EPROJ $EPROJ/fasta
			find $EPROJ/fasta -type f -exec gunzip {} \;
			
			echo -e "\tRunning focus"
			singularity exec --bind $PWD:/focus /home/edwa0468/Projects/focus/sif/focus_v1.8.0_d95c4fb1ae57.sif \
				focus -q /focus/$EPROJ/fasta -o /focus/$EPROJ/${EPROJ}_focus -k 7 -t 16 -p $EPROJ

			find $EPROJ/${EPROJ}_focus -type f -exec gzip {} \;

			echo -e "\tRunning superfocus"
			TMP=$(mktemp -d -p .)
			singularity exec --bind $PWD/:/superfocus,/home/edwa0468/Projects/superfocus_db:/superfocus_db \
				 /home/edwa0468/Projects/superfocus/sif/superfocus_v1.6.0_b91c0c41d6a5.sif \
				superfocus -q /superfocus/$EPROJ/fasta -t 16 -dir /superfocus/$EPROJ/${EPROJ}_superfocus \
					-a mmseqs2 -db DB_95 -b /superfocus_db -d -o $EPROJ -tmp /superfocus/$TMP

			find $EPROJ/${EPROJ}_superfocus  -type f -exec gzip {} \;
			rm -rf $EPROJ/fasta $TMP
		fi 
	done
	cd $WD
done

