#!/bin/bash
#SBATCH --job-name=Phables
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o phables-%j.out
#SBATCH -e phables-%j.err


# Assuming we have:
# phables/$DIR
# phables/$DIR/$DIR.graph.gfa
# phables/$DIR/fastq/$DIR_1.fastq.gz
# phables/$DIR/fastq/$DIR_2.fastq.gz

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <directory> with R1/R2 files and graph.gfa"
    exit 1
fi

DIR=$1

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm
PHABLES=/home/edwa0468/software_1018/phables/sif/phables_v0.6_gogo.sif
singularity exec --bind /scratch/pawsey1018/edwa0468/tmp/conda:/conda,$PWD/$DIR:/phables,$HOME/gurobi.lic:/opt/gurobi/gurobi.lic $PHABLES \
	phables run --input /phables/$DIR.graph.gfa --reads /phables/fastq/ --output /phables/phables --threads 32 --prefix $DIR --mincov 1


