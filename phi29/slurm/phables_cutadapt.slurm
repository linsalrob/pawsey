#!/bin/bash
#SBATCH --job-name=phablesCA
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH -o phablescut_%j.out
#SBATCH -e phablescut_%j.err

set -euo pipefail

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm

PHAB=cutadapt_phables
for BC in RB01 RB04 RB05 RB08 RB09 RB10 RB11; do 
	singularity exec --bind /scratch/pawsey1018/edwa0468/tmp/conda:/conda,$PWD/$PHAB/$BC:/phables,$HOME/gurobi.lic:/opt/gurobi/gurobi.lic sif/phables_v0.6_gogo.sif \
		phables run --input /phables/assembly_graph.gfa --reads /phables/fastq --output /phables/phables --threads 32 --prefix $BC --mincov 1 --longreads
done


