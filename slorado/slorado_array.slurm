#!/bin/bash --login
#SBATCH --partition=gpu-highmem
#SBATCH --gres=gpu:8
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=1-0
#SBATCH -o slorado-%A_%a.out
#SBATCH -e slorado-%A_%a.err

set -euo pipefail

# usage: sbatch --account=${PAWSEY_PROJECT}-gpu --array=1:N:1 slorado_array.slurm


if [[ $# -eq 0 ]]; then
	echo "usage: sbatch --account=${PAWSEY_PROJECT}-gpu --array=1-JOBS:1 slorado_array.slurm BLOW5_DIR" >&2;
fi

BLOW5DIR=$1
BASE=$(dirname $BLOW5DIR)
FASTQDIR=$BASE/fastq_arr
mkdir -p $FASTQDIR

# you may change the model one of the available:  dna_r10.4.1_e8.2_400bps_fast@v4.2.0  dna_r10.4.1_e8.2_400bps_hac@v4.2.0  dna_r10.4.1_e8.2_400bps_sup@v4.2.0
# MODEL=dna_r10.4.1_e8.2_400bps_sup@v4.2.0
MODEL=dna_r10.4.1_e8.2_400bps_hac@v5.0.0
# batch size must be adjusted so that we do not overflow the GPU memory: tested to work:  2000 for fast, 500 for hac and 200 for sup
BATCH_SIZE=500

# where did you install slorado
SLORADO_DIR=/scratch/$PAWSEY_PROJECT/$USER/slorado/slorado-v0.3.0-beta
SLORADO=${SLORADO_DIR}/bin/slorado


INPUTS=($(find ${BLOW5DIR} -name "*.blow5" -printf "%f\n"))
BLOW5=${INPUTS[$SLURM_ARRAY_TASK_ID]}

FASTQ=${BLOW5/blow5/fastq}

echo -e "Starting task ID $SLURM_ARRAY_TASK_ID at " `date` " for  ${BLOW5DIR}/${BLOW5} -> ${FASTQDIR}/${FASTQ}"
srun /usr/bin/time -v ${SLORADO} basecaller ${SLORADO_DIR}/models/${MODEL} ${BLOW5DIR}/${BLOW5} -o ${FASTQDIR}/${FASTQ} -t64 -C ${BATCH_SIZE}
