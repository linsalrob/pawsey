# Running GTDB on Pawsey

(Hopefully using singularity ...)

# Download the GTDB databases

sbatch download_gtdb.sbatch

# Create the sif file.

NOte that I just make this in the ~/Databases/GTDB directory so that the database and the container are in the same place.

module load pawseyenv/2023.08
module load singularity/3.11.4-slurm
mkdir ~/Databases/GTDB/sif
singularity pull --dir ~/Databases/GTDB/sif docker://ecogenomic/gtdbtk
ls ~/Databases/GTDB/sif
