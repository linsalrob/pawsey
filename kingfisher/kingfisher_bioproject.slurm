#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=kingfisher
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32GB
#SBATCH -o kingfisher-%j.out
#SBATCH -e kingfisher-%j.err

set -euo pipefail

if [[ $# -eq 0 ]]; then
	echo "kingfisher.slurm <PROJECT ID> (e.g. SRR123456 or PRJNA516870)"
	exit; 
fi

module load singularity/4.1.0-slurm


# For a single run or multiple runs
# singularity run --bind `pwd`:/data /home/edwa0468/GitHubs/pawsey/kingfisher/sif/kingfisher_0.4.1.sif get -r $1 -m ena-ftp

# for an entire bioproject
singularity run --bind `pwd`:/data /home/edwa0468/GitHubs/pawsey/kingfisher/sif/kingfisher_0.4.1.sif get -p $1 -m ena-ftp aws-http prefetch aws-cp --download-threads 16


