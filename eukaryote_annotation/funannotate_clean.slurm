#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=funannotate
#SBATCH --time=96:00:00
#SBATCH --partition=long
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=230GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail

if [[ $# -eq 0 ]]; then
	echo "funannotate.slurm <fasta of contigs>"
	exit; 
fi

module load singularity/4.1.0-slurm


# Clean the genome

# This sets the environment variable FUNANNOTATE_DB in the singularity container. Note that below we bind that to our database location
export SINGULARITYENV_FUNANNOTATE_DB=/funannotate
singularity run --bind $HOME/Databases/funannotate:/funannotate,`pwd`:/data /home/edwa0468/GitHubs/pawsey/eukaryote_annotation/sif/funannotate_latest.sif funannotate clean -i /data/$1  -o /data/${1/.fa/.clean.fa} --cpus 256



