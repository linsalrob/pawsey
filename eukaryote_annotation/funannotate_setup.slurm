#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=funannotate_setup
#SBATCH --time=24:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail


module load singularity/4.1.0-slurm

DEST=$HOME/Databases/funannotate
if [[ -e $DEST ]]; then
	rm -rf $DEST;
fi
mkdir -p $DEST

# This sets the environment variable FUNANNOTATE_DB in the singularity container. Note that below we bind that to our database location

export SINGULARITYENV_FUNANNOTATE_DB=/funannotate
singularity run --bind $HOME/Databases/funannotate:/funannotate,`pwd`:/data /home/edwa0468/GitHubs/pawsey/eukaryote_annotation/sif/funannotate_latest.sif funannotate setup --wget -d $DEST

