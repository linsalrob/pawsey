#!/bin/bash
#SBATCH --job-name=envhogDld
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=copy
#SBATCH --mem=64G
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

# download the envhog protein fastas and the tsv file that describes them

set -euo pipefail
trap 'echo "Error on line $LINENO: $BASH_COMMAND"' ERR

DBDIR=/scratch/$PAWSEY_ACCOUNT/$USER/Databases/envhog

mkdir -p $DBDIR
cd $DBDIR

# URL is from http://envhog.u-ga.fr/envhog/
# All proteins in fasta
FAAURL=http://envhog.u-ga.fr/envhog/enVhog_prots_sequences.faa.gz
# Link between original studies protein IDs and enVhog IDs in TSV format 
IDURL=http://envhog.u-ga.fr/envhog/enVhog_protNames2enVhogID.tsv.gz

curl -LO $FAAURL &
curl -LO $IDURL &

wait

# next we need to format these but we need an mmseqs environment
eval "$(conda shell.bash hook)"
conda activate bioinfie

mmseqs createdb enVhog_prots_sequences.faa.gz envhog
mmseqs createindex envhog $(mktemp -d)
