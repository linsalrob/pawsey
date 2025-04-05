#!/bin/bash --login
#SBATCH --partition=gpu-highmem
#SBATCH --gres=gpu:8
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=1-0
#SBATCH -o slorado-%j.out
#SBATCH -e slorado-%j.err

# usage: sbatch --account=${PAWSEY_PROJECT}-gpu slorado.slurm

BASE=/scratch/$PAWSEY_PROJECT/$USER/CF_PromethION_matched_samples_Run2/20250314_1541_P2S-02700-B_PBA71146_20fca30d/

BLOW5DIR=$BASE/blow5
FASTQDIR=$BASE/fastq
mkdir -p $FASTQDIR

# you may change the model one of the available:  dna_r10.4.1_e8.2_400bps_fast@v4.2.0  dna_r10.4.1_e8.2_400bps_hac@v4.2.0  dna_r10.4.1_e8.2_400bps_sup@v4.2.0
# MODEL=dna_r10.4.1_e8.2_400bps_sup@v4.2.0
MODEL=dna_r10.4.1_e8.2_400bps_hac@v4.2.0
# batch size must be adjusted so that we do not overflow the GPU memory: tested to work:  2000 for fast, 500 for hac and 200 for sup
BATCH_SIZE=500

# where did you install slorado
SLORADO_DIR=/scratch/$PAWSEY_PROJECT/$USER/slorado/slorado-v0.2.0-beta
SLORADO=${SLORADO_DIR}/bin/slorado


for BLOW5 in $(find $BLOW5DIR -type f -printf "%f\n"); do
	FASTQ=${BLOW5/blow5/fastq}; 
	echo -e "$BLOW5 -> $FASTQ"
	srun /usr/bin/time -v ${SLORADO} basecaller ${SLORADO_DIR}/models/${MODEL} ${BLOW5DIR}/${BLOW5} -o ${FASTQDIR}/${FASTQ} -t64 -C ${BATCH_SIZE}
done
