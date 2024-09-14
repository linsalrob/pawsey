# Using Superfocus with singularity

We have made a superfocus dockerfile that we can create into a `.sif` image.

The current tag is 5abbef95a6ca


# Load the singularity module and create a new image


NOTE: There is (currently) an issue with singularity 4.1.0. If it persists, here is how to load a previous image:

```
module load pawseyenv/2023.08
module load singularity/3.11.4-slurm
```

Otherwise, this will make a superfocus `.sif`

```
export TAG=5abbef95a6ca
module load singularity/4.1.0-slurm
mkdir sif tmp
# remember that singularity needs the full path (not a relative path, like tmp)
export SINGULARITY_TMPDIR=$PWD/tmp/
singularity pull --dir sif docker://linsalrob/superfocus:v1.6.0_${TAG}
```

Now, you need to link the directories so that everything will work.

Assuming you have  

/home/edwa0468/Projects/superfocus
/home/edwa0468/Projects/superfocus/fasta/

and
/home/edwa0468/Projects/superfocus_db/db/
/home/edwa0468/Projects/superfocus_db/db/database_PKs.txt
/home/edwa0468/Projects/superfocus_db/db/static/mmseqs2

Then this should work in a slurm job (see superfocus.slurm)

```
singularity exec --bind $PWD/:/superfocus,/home/edwa0468/Projects/superfocus_db:/superfocus_db sif/superfocus_v1.6.0_5abbef95a6ca.sif \
	superfocus -q /superfocus/fasta -t 16 -dir /superfocus/superfocus -a mmseqs2 -db DB_95 -b /superfocus_db -o ERZ477431
```

