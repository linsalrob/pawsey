#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=md
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8GB
#SBATCH -o md-%j.out
#SBATCH -e md-%j.err

for ID in $(cat ebi_projects.txt); do URL="https://www.ebi.ac.uk/ena/browser/api/xml/${ID}?download=true"; wget -O metadata/$ID.xml $URL; done
