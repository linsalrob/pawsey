#!/bin/bash
#SBATCH --job-name=phables
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o phables-%A_%a.out
#SBATCH -e phables-%A_%a.err

set -euo pipefail

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm


#for BC in barcode01  barcode04  barcode05  barcode08  barcode10  barcode11; do 
for BC in barcode10  barcode11; do 
	singularity exec --bind /scratch/pawsey1018/edwa0468/tmp/conda:/conda,$PWD/phables/$BC:/phables,$HOME/gurobi.lic:/opt/gurobi/gurobi.lic sif/phables_v0.6_gogo.sif \
		phables run --input /phables/assembly_graph.gfa --reads /phables/fastq --output /phables/phables --threads 32 --prefix $BC --mincov 1 --longreads
done


