#!/bin/bash
#SBATCH --job-name=checkm
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=48GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
eval "$(conda shell.bash hook)"

# if you need to recreate the checkm conda environment, use:
# TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
# mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP numpy matplotlib pysam hmmer prodigal pplacer
# pip3 install checkm-genome

TMP=bd5339834b62
conda activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

export CHECKM_DATA_PATH=$HOME/Databases/checkm/

if [[ ! -e $CHECKM_DATA_PATH/selected_marker_sets.tsv ]]; then echo "We will need to install checkm databases in $CHECKM_DATA_PATH" >&2; fi

if [[ $# -ne 2 ]]; then 
	echo "$0  <input_directory> <output_directory>" >&2
	exit; 
fi



# create the checkm databases if we don't have them


if [[ ! -e $CHECKM_DATA_PATH/selected_marker_sets.tsv ]]; then
	cd $CHECKM_DATA_PATH
	rm -rf distributions genome_tree hmms hmms_ssu img pfam test_data
	wget https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz
	tar xf checkm_data_2015_01_16.tar.gz
fi 


checkm lineage_wf -t 22 -x fna $1 $2


