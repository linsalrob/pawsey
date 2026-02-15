#!/bin/bash
#SBATCH --job-name=ge_run
#SBATCH --account=pawsey1018-gpu
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH -o slurm/%x-%j.out
#SBATCH -e slurm/%x-%j.err

# I explicitly don't want ths, because if the code crashes, I want to carry on with the next genome :)
# set -euo pipefail
# trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR



VENV_DIR="/scratch/pawsey1018/edwa0468/software/pip/genome_entropy"
if [[ ! -e "$VENV_DIR" ]]; then 
	echo "Please run the installer to create the venv" >&2;
	exit 1;
fi

source "$VENV_DIR/bin/activate"

ENCSZ=1000000

mkdir -p bacteria_outputs/

for F in $(find bacteria -type f -printf "%f\n"); do 
	J=$(basename $F .gbff.gz); 
	echo $F $J; 
	if [[ ! -e bacteria_outputs/$J.json.gz ]]; then
		genome_entropy run -g bacteria/$F -o bacteria_outputs/$J.json.gz --encoding-size $ENCSZ
	fi
done


