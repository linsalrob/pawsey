#!/bin/bash --login
#SBATCH --partition=gpu-highmem
#SBATCH --job-name=slorado
#SBATCH --gres=gpu:8
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:20:00
#SBATCH -o %x-%A_%a.out
#SBATCH -e %x-%A_%a.err

set -euo pipefail

# usage: sbatch --account=${PAWSEY_PROJECT}-gpu --array=1:N:1 slorado_sup_array.slurm

# note: the 20 minute time came from job id 43758188 which has ~100 jobs

if [[ $# -eq 0 ]]; then
	echo -n "Usage:\n\n JOBS=$(ls pod5/ | wc -l)" >&2
	echo " sbatch --account=${PAWSEY_PROJECT}-gpu --array=1-$JOBS:1 ~/GitHubs/pawsey/slorado/slorado_sup_array.slurm blow5/ ">&2
fi

BLOW5DIR=$1
BASE=$(dirname $BLOW5DIR)
FASTQDIR=$BASE/fastq_sup_arr
mkdir -p $FASTQDIR

# To find the models, look on Benson's release page (https://github.com/BonsonW/slorado/releases)
# Current models:
# 	dna_r10.4.1_e8.2_400bps_fast@v5.0.0, dna_r10.4.1_e8.2_400bps_hac@v5.0.0, dna_r10.4.1_e8.2_400bps_sup@v5.0.0
#       rna004_130bps_fast@v5.1.0, rna004_130bps_fast@v5.1.0, rna004_130bps_fast@v5.1.0
#
MODEL=dna_r10.4.1_e8.2_400bps_sup@v5.0.0

# batch size must be adjusted so that we do not overflow the GPU memory: tested to work:  2000 for fast, 500 for hac and 200 for sup
BATCH_SIZE=100

# where did you install slorado
SLORADO_VER=v0.5.0-beta
SLORADO_DIR=/scratch/$PAWSEY_PROJECT/$USER/slorado/slorado-$SLORADO_VER
SLORADO=${SLORADO_DIR}/bin/slorado


INPUTS=($(find ${BLOW5DIR} -name "*.blow5" -printf "%f\n"))
BLOW5=${INPUTS[$SLURM_ARRAY_TASK_ID-1]}

FASTQ=${BLOW5/blow5/fastq}

echo -e "Starting task ID $SLURM_ARRAY_TASK_ID at " `date` " for  ${BLOW5DIR}/${BLOW5} -> ${FASTQDIR}/${FASTQ}"
srun ${SLORADO} basecaller ${SLORADO_DIR}/models/${MODEL} ${BLOW5DIR}/${BLOW5} -o ${FASTQDIR}/${FASTQ} -t64 -C ${BATCH_SIZE}
echo -e "Fin at " `date`
