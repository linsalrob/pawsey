#!/bin/bash
#SBATCH --job-name=MGNify_upload
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=32G
#SBATCH -o slurm_logs/upload-%j.out
#SBATCH -e slurm_logs/upload-%j.err

###################################################################################
#                                                                                 #
# Check for the presence of a file DONE to indicate we are done, and then         #
# upload the data to both Acacia (just the resolved genomes) and Teams            #
# (all the data)                                                                  #
#                                                                                 #
#                                                                                 #
###################################################################################



set -euo pipefail

eval "$(conda shell.bash hook)"
conda activate rclone

for DONE in $(find -name DONE -type f); do 
	WD=$(basename $(dirname $DONE));
	if [[ -e $WD/UPLOADED ]]; then
		echo "$WD: Already uploaded" >&2
		continue
	fi
	DATE=`date`
	echo "$WD: Uploading at $DATE" >&2;
	PROJECTID=$(echo $WD | cut -d '_' -f 1)
	GFAID=$(echo $WD | cut -d '_' -f 2)
	if [[ ! -e $WD/UPLOADED_PHABLES ]]; then
		rclone copy $WD/phables/ PhablesMGNify:General/data/phables/$PROJECTID/$GFAID/ & 
	fi
	if [[ ! -e $WD/UPLOADED_RESOVED ]]; then
		rclone copy $WD/phables/${WD}_resolved_phages.tgz Acacia_pawsey1018:mgnify/phables/$PROJECTID/$GFAID/ &
	fi

	wait
	touch $WD/UPLOADED_RESOVED
	touch $WD/UPLOADED_PHABLES
	touch $WD/UPLOADED
done

