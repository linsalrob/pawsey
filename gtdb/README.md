# Running GTDB on Pawsey

(Hopefully using singularity ...)

# Download the GTDB databases

sbatch download_gtdb.sbatch

# Create the sif file.

Note that I just make this in the ~/Databases/GTDB directory so that the database and the container are in the same place.

```
module load pawseyenv/2023.08
module load singularity/3.11.4-slurm
mkdir ~/Databases/GTDB/sif
singularity pull --dir ~/Databases/GTDB/sif docker://ecogenomic/gtdbtk
ls ~/Databases/GTDB/sif
```


Submit the job to run GTDB-Tk. Note that it is important to use the full paths.

```
sbatch gtdb.slurm /home/edwa0468/Projects/CF/crAss/MixedAssemblies/cross_assembly/bins /scratch/pawsey1018/edwa0468/Databases/GTDB/release226 /scratch/pawsey1018/edwa0468/Databases/GTDB/sif
```


