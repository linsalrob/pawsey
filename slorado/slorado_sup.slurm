#!/bin/bash --login
#SBATCH --partition=gpu-dev
#SBATCH --job-name=slorado
#SBATCH --gres=gpu:8
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=0-4
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# usage: sbatch --account=${PAWSEY_PROJECT}-gpu ~/GitHubs/pawsey/slorado/slorado.slurm

BASE=.
BLOW5DIR=$BASE/blow5
FASTQDIR=$BASE/fastq_sup_arr
mkdir -p $FASTQDIR

# you may change the model one of the available:  dna_r10.4.1_e8.2_400bps_fast@v4.2.0  dna_r10.4.1_e8.2_400bps_hac@v4.2.0  dna_r10.4.1_e8.2_400bps_sup@v4.2.0
# MODEL=dna_r10.4.1_e8.2_400bps_sup@v4.2.0
MODEL=dna_r10.4.1_e8.2_400bps_sup@v5.0.0

# batch size must be adjusted so that we do not overflow the GPU memory: tested to work:  2000 for fast, 500 for hac and 200 for sup
BATCH_SIZE=200

# where did you install slorado
SLORADO_VER=v0.5.0-beta
SLORADO_DIR=/scratch/$PAWSEY_PROJECT/$USER/slorado/slorado-$SLORADO_VER
SLORADO=${SLORADO_DIR}/bin/slorado

# we write to a tmp dir in case we time out
TMP=$(mktemp -d -p /scratch/$PAWSEY_PROJECT/$USER/tmp)
for BLOW5 in $(find $BLOW5DIR -type f -printf "%f\n" | shuf); do
	FASTQ=${BLOW5/blow5/fastq}; 
	if [[ -e ${FASTQDIR}/${FASTQ} ]]; then
		echo "${FASTQDIR}/${FASTQ} already exists. Skipped"
		continue
	fi
	echo -e "$BLOW5 -> $FASTQ"
	srun ${SLORADO} basecaller ${SLORADO_DIR}/models/${MODEL} ${BLOW5DIR}/${BLOW5} -o ${TMP}/${FASTQ} -t64 -C ${BATCH_SIZE}
	mv ${TMP}/${FASTQ} ${FASTQDIR}/${FASTQ}
done
