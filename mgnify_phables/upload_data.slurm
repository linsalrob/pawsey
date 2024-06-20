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

	PID1=0
	PID2=0

	TEST=$(rclone ls PhablesMGNify:General/data/phables/$PROJECTID/$GFAID/${WD}_phables.tgz) || true
	if [[ -z $TEST ]]; then
		rclone copy $WD/phables/ PhablesMGNify:General/data/phables/$PROJECTID/$GFAID/ & 
		PID1=$!
	else
		echo "$WD already uploaded to teams" >&2;
		touch $WD/UPLOAD_MGNIFY
	fi


	TEST=$(rclone ls Acacia_pawsey1018:mgnify/phables/$PROJECTID/$GFAID/${WD}_resolved_phages.tgz) || true
	if [[ -z $TEST ]]; then
		rclone copy $WD/phables/${WD}_resolved_phages.tgz Acacia_pawsey1018:mgnify/phables/$PROJECTID/$GFAID/ &
		PID2=$!
	else
		echo "$WD already uploaded to Acacia" >&2;
		touch $WD/UPLOAD_RESOLVED
	fi

	EXIT_STATUS=0
	if [[ $PID1 > 0 ]]; then
		wait $PID1
		PID1_EXIT=$?
		EXIT_STATUS=$((EXIT_STATUS + PID1_EXIT))
		if [[ $PID1_EXIT == 0 ]]; then 
			touch $WD/UPLOAD_MGNIFY
		fi
	fi
			
	if [[ $PID2 > 0 ]]; then
		wait $PID2
		PID2_EXIT=$?
		EXIT_STATUS=$((EXIT_STATUS + PID2_EXIT))
		if [[ $PID2_EXIT == 0 ]]; then 
			touch $WD/UPLOAD_RESOLVED
		fi
	fi

	if [[ $EXIT_STATUS == 0 ]]; then
		touch $WD/UPLOADED
	fi
done

