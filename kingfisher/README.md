# Kingfisher

Ben's amazing tool to download from NCBI, ENA, etc.

How to install and run on Pawsey.


## Get the tag

[Get the latest tag from the Docker releases](https://hub.docker.com/r/wwood/kingfisher/tags)


## Create a singularity file

Find the current singularity version
```
module avail singu
```

Now create the sif file

```
module load singularity/4.1.0-slurm
mkdir sif
singularity pull --dir sif docker://wwood/kingfisher:0.4.1
```


