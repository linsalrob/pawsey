#!/bin/bash
#SBATCH --job-name=MGNify_Phables
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o phables-%j.out
#SBATCH -e phables-%j.err

set -euo pipefail

if [[ -z $PROJECTID ]] || [[ -z $GFAID ]]; then
	echo "Please define PROJECTID and GFAID as environment variables (remember no .gz on GFAID" >&2;
	exit
fi

WD=${PROJECTID}_${GFAID}
echo "Project $PROJECTID GFA: $GFAID.gfa.gz WORK DIRECTOY $WD" >&2

# PROJECTID=ERP127968
# note the lack of the .gz here .... !
# GFAID=ERZ1764889

# step 1, get the fastq files

mkdir -p $WD/fastq $WD/phables
python ~/GitHubs/pawsey/mgnify_phables/bioproject_accession_to_fastq.py -p $PROJECTID -a $GFAID -d $WD/fastq -v

# step 2, get the gfa file
eval "$(conda shell.bash hook)"
conda activate rclone
rclone copy PhablesMGNify:General/data/gfa/$PROJECTID/$GFAID.gfa.gz $WD/
gunzip $WD/$GFAID.gfa.gz 
rclone copy $WD/fastq/ PhablesMGNify:General/data/fastq/$PROJECTID/$GFAID &



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


rclone copy $WD/phables/ PhablesMGNify:General/data/phables/$PROJECTID/$GFAID/
rclone copy $WD/phables/${WD}_resolved_phages.tgz Acacia_pawsey1018:mgnify/phables/$PROJECTID/$GFAID/${WD}_resolved_phages.tgz

wait

rm -rf $WD
