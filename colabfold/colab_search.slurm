#!/bin/bash
#SBATCH --job-name=colabsearch
#SBATCH --partition=gpu-dev
#SBATCH --gres=gpu:8
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=0-4
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# Don't forget to submit this using the right code:
# sbatch --account=${PAWSEY_PROJECT}-gpu ~/GitHubs/pawsey/colabfold/colab_search.slurm 

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm
export containerImage=/scratch/$PAWSEY_ACCOUNT/$USER/colabfold/colabfold_rocm6_cpuTF.sif



singularity exec --rocm "$containerImage" colabfold_batch --num-models 1 $1 $2
