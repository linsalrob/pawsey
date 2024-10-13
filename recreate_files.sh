#!/bin/bash

echo "Downloading NCBI Databases"
cd /home/edwa0468/Databases/NCBI/taxonomy/current
sbatch /home/edwa0468/slurm/ncbi_taxonomy.slurm

echo "Refreshing githubs"
cd ~/GitHubs
for P in atavide_lite  CF_Data_Analysis  EdwardsLab; do
	if [[ -e $P ]]; then
		cd $P;
		git pull;
		cd ~/GitHubs
	else
		git clone git@github.com:linsalrob/${P}.git
	fi
done

