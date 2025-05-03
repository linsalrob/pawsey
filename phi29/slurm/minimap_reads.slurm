#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=minimap_rds
#SBATCH --time=0-4
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --mem=128G
#SBATCH -o minimaprds-%j.out
#SBATCH -e minimaprds-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/minimap

if [[ $# -ne 3 ]]; then
	echo "$0 <reads> <contigs> <outputfile>";
	exit 2
fi

# samtools flag 3588
#    4 read unmapped (0x4)
#  512 read fails platform/vendor quality checks (0x200)
# 1024 read is PCR or optical duplicate (0x400)
# 2048 supplementary alignment (0x800)

minimap2 -t 64 -ax map-ont $2 $1 | samtools view -F 3588 -b --threads 16  | samtools sort -@ 16 -o $3 -
samtools index $3

