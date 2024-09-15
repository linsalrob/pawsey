#!/bin/bash
#SBATCH --job-name=ena_dld
#SBATCH --account=pawsey1018
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH -o slurm_logs/download_all_data-%A_%a.out
#SBATCH -e slurm_logs/download_all_data-%A-%a.err

set -euo pipefail
eval "$(conda shell.bash hook)"
conda activate rclone

BIOP=$(head -n $SLURM_ARRAY_TASK_ID ebi_projects_needed.txt | tail -n 1)
OUTDIR="ena/$BIOP/fastq"
mkdir --parents $OUTDIR
python ~/GitHubs/pawsey/mgnify_phables/bioproject_to_fastq.py -p $BIOP -d $OUTDIR -v

##
## I remove this: #SBATCH --partition=copy
## 
