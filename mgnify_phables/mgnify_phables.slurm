#!/bin/bash
#SBATCH --job-name=MGNify_Phables
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o phables-%j.out
#SBATCH -e phables-%j.err


PROJECTID=ERP127968
GFAID=ERZ1764889.gfa.gz

# step 1, get the fastq files

mkdir -p $PROJECTID/fastq $PROJECTID/phables
python ~/GitHubs/pawsey/mgnify_phables/bioproject_to_fastq.py -p $PROJECTID -d $PROJECTID/fastq

# step 2, get the gfa file
eval "$(conda shell.bash hook)"
# note that bioinformatics has the wrong mmseqs2 version :(
conda activate rclone
rclone copy PhablesMGNify:General/data/gfa/$PROJECTID/$GFAID $PROJECTID/
rclone copy $PROJECTID/fastq/ PhablesMGNify:General/data/fastq/$PROJECTID/ &



module load singularity/3.11.4-slurm
singularity exec --bind /scratch/pawsey1018/edwa0468/tmp/conda:/conda,$PWD/$PROJECTID:/phables,$HOME/gurobi.lic:/opt/gurobi/gurobi.lic testy/phables_v0.6_gogo.sif phables run --input /phables/$GFAID --reads /phables/fastq/ --output /phables/phables --threads 32

wait
