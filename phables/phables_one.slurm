#!/bin/bash
#SBATCH --job-name=Phables
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o phables-%j.out
#SBATCH -e phables-%j.err


module load singularity/3.11.4-slurm
singularity exec --bind /scratch/pawsey1018/edwa0468/tmp/conda:/conda,$PWD/testy/Sim_Phage/:/phables,$PWD/gurobi.lic:/opt/gurobi/gurobi.lic testy/phables_v0.6_gogo.sif phables run --input /phables/assembly_graph_after_simplification.gfa --reads /phables/reads/ --output /phables/phables --threads 32
