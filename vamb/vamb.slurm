#!/bin/bash
#SBATCH --job-name=VAMBall
#SBATCH --time=0-4
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err
#SBATCH --gres=gpu:8
#SBATCH --partition=gpu-dev

set -euo pipefail

# Please see the vamb_install.slurm script to create the 
# virtual environment for vamb. NOTE: Do not use conda, because 
# we need a rcom install, not nvidia.

VENV_DIR="/scratch/pawsey1018/edwa0468/software/pip/vamb"
if [[ ! -e "$VENV_DIR" ]]; then 
	echo "Please run vamb_install.slurm to create the vamb virtual environment" >&2
	exit 1;
fi

module load rocm/6.2.4
source "$VENV_DIR/bin/activate"

OUTDIR=vamb

if [ ! -e $OUTDIR/contigs.mmi ]; then minimap2 -I100G -d $OUTDIR/contigs.mmi $OUTDIR/contigs.fna.gz; fi

vamb bin default -p 16 --cuda --outdir $OUTDIR/vamb --fasta $OUTDIR/contigs.fna.gz --bamdir mapped_reads/merged
python ~/atavide_lite/bin/vamb_create_fasta.py $OUTDIR/contigs.fna.gz $OUTDIR/vamb/vae_clusters.tsv 20000 $OUTDIR/bins

