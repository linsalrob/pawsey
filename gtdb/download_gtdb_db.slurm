#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=RobSimple
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2GB
#SBATCH -o slurm-%j.out
#SBATCH -e slurm-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR


mkdir -p ~/Databases/GTDB
cd ~/Databases/GTDB

# Download GTDB
wget https://data.ace.uq.edu.au/public/gtdb/data/releases/latest/auxillary_files/gtdbtk_package/full_package/gtdbtk_data.tar.gz
tar -xvzf gtdbtk_data.tar.gz



