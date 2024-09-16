#!/bin/bash
#SBATCH --job-name=MGNify_Phables
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o slurm_logs/phables-%A_%a.out
#SBATCH -e slurm_logs/phables-%A-%a.err

###################################################################################
#                                                                                 #
# Run phables on a lot of mgnfy data. This version uses                           #
# the  ~/GitHubs/pawsey/mgnify_phables/bioproject_accession_to_fastq_local.py     #
# script which does not download the fastq files if we already have them          #
#                                                                                 #
# Use the downloader to get the fastq files separately, and then                  #
# run this on a per project basis.                                                #
#                                                                                 #
# Remember you can only run 4 jobs concurrently because of the gurobi             #
# license                                                                         #
#                                                                                 #
#                                                                                 #
#                                                                                 #
###################################################################################


set -euo pipefail
DF=$1
if [[ -z $DF ]]; then
	echo -e "Please define a data file with one entry per line like this:\nPhablesMGNify:General/data/gfa/ERP104203/ERZ1756831.gfa.gz" >&2;
	exit
fi


# To run this
# sbatch --array=1-999%5 mgnify_phables_array.slurm gfa_data.txt.1
#
# After running, you might want to remove any tar archives that are essentially empty
# copy the entire archive to a temp directory and then something like this will delete the empty ones
# find * -type f -size -300c -exec rclone delete Acacia_pawsey1018:mgnify/phables/{} \;

MGN=$(head -n $SLURM_ARRAY_TASK_ID $DF | tail -n 1)
GFAID=`basename $MGN .gfa.gz`
MGNDIR=`dirname $MGN`
PROJECTID=`basename $MGNDIR`

if [[ ! -e ena/$PROJECTID ]]; then
	echo "ERROR: ena/$PROJECTID not found" >&2;
fi

WD=${PROJECTID}_${GFAID}
echo "Project $PROJECTID GFA: $GFAID.gfa.gz WORK DIRECTOY $WD" >&2

# PROJECTID=ERP127968
# note the lack of the .gz here .... !
# GFAID=ERZ1764889

# check if the output exists on the remote
eval "$(conda shell.bash hook)"
conda activate rclone

TEST=$(rclone ls Acacia_pawsey1018:mgnify/phables/$PROJECTID/$GFAID/${WD}_resolved_phages.tgz)
# -z TEST will be TRUE if the file does NOT exist
# ! -z $TEST will be TRUE if the file DOES exist (it is not empty) 
if [[ ! -z $TEST ]]; then 
	echo "Acacia_pawsey1018:mgnify/phables/$PROJECTID/$GFAID/${WD}_resolved_phages.tgz already exists. Not overwriting" >&2;
	exit 0;
fi


# If we already have the GFA file in the WD then assume something went wrong with the phables run. Skip the downloads!
#

if [[ ! -e $WD/fastq ]]; then
	# step 1, get the fastq files
	mkdir -p $WD/fastq $WD/phables
	python ~/GitHubs/pawsey/mgnify_phables/bioproject_accession_to_fastq_local.py -l ena/$PROJECTID/fastq/ -p $PROJECTID -a $GFAID -d $WD/fastq -v -c
fi

if [[ ! -e $WD/$GFAID.gfa ]]; then
	# step 2, get the gfa file
	rclone copy PhablesMGNify:General/data/gfa/$PROJECTID/$GFAID.gfa.gz $WD/
	gunzip $WD/$GFAID.gfa.gz 
fi

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm
singularity exec --bind /scratch/pawsey1018/edwa0468/tmp/conda:/conda,$PWD/$WD:/phables,$HOME/gurobi.lic:/opt/gurobi/gurobi.lic sif/phables_v0.6_gogo.sif \
	phables run --input /phables/$GFAID.gfa --reads /phables/fastq/ --output /phables/phables --threads 32 --prefix $GFAID --mincov 1

# tar the output files to make sending/getting easier

tar --remove-files -zcf $WD/phables/${WD}_preprocess.tgz -C $WD/phables/ preprocess &
tar zcf $WD/phables/${WD}_resolved_phages.tgz -C $WD/phables/phables/  resolved_phages/ &
tar --remove-files -zcf $WD/phables/${WD}_phables.tgz -C $WD/phables/ phables &
tar --remove-files -zcf $WD/phables/${WD}_log.tgz -C $WD/phables/ logs config.yaml phables.log &
tar --remove-files -zcf $WD/phables/${WD}_postprocess.tgz -C $WD/phables/ postprocess &

wait

touch $WD/DONE

