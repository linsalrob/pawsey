#!/bin/bash
#SBATCH --job-name=reneo
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o reneo-%j.out
#SBATCH -e reneo-%j.err

set -euo pipefail

module load singularity/4.1.0-slurm

singularity exec --bind /home/edwa0468/scratch_1018/software/miniconda3/:/conda,/home/edwa0468/Projects/reneo/reneo:/reneo,/home/edwa0468/gurobi.lic:/opt/gurobi/gurobi.lic \
	sif/reneo_v0.4.0_edb2e466f3e9.sif  reneo run --input /reneo/assemblyGraph.gfa --reads /reneo/reads  --output /reneo/reneo_out --threads 32  
