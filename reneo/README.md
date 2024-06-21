# Create the dockerfile

This dockerfile uses [micromamba](https://mamba.readthedocs.io/en/latest/user_guide/micromamba.html) instead of conda/mamba

Lets create a docker image. Note that you need `sudo` access for this, so I do it on an AWS or Google Cloud instance.

First, we install docker, and then remove any existing images. You might skip these steps, but if you are working on
a cloud instance, you may run out of disk space!

```
apt install -y docker.io
# remove any existing docker images
docker images
docker images | awk '{print $3}' | grep -v IM | xargs docker rmi -f {}
```

Now, in a directory with the Dockerfile, you can build docker:

```
# build a new image
docker build -t reneo .
```

Next, lets share it. I append the current version and the build hash sum to the tag
because that makes it unique, and often I have to build a few times to get it to work properly!

```
# tag it and upload to docker quay
docker login -u linsalrob
docker tag reneo linsalrob/reneo:v0.4.0_387f995e969d
docker push linsalrob/reneo:v0.4.0_387f995e969d
```

If you want to see what's on the image or check things out, you can also run it locally before sharing it

```
# run the image to see what's there
docker run -i -t linsalrob/reneo:v0.4.0_387f995e969d /bin/bash
```

Run the image with the license and everything 

```
docker run --volume=$PWD/data/reneo:/reneo --volume=$PWD/gurobi.lic:/opt/gurobi/gurobi.lic:ro linsalrob/reneo:v0.4.0_387f995e969d reneo run --input /reneo/assemblyGraph.gfa --reads /reneo/reads  --output /reneo/reneo_out --threads 2
```

Now that we have an image we think works, we switch over to our singularity host (e.g. pawsey), and make
the image:


# Load the singularity module and create a new image

```
module load singularity/4.1.0-slurm
mkdir sif tmp
# remember that singularity needs the full path (not a relative path, like tmp)
export SINGULARITY_TMPDIR=$PWD/tmp/
singularity pull --dir sif docker://linsalrob/reneo:v0.4.0_387f995e969d
```

Now, you need to link the directories so that everything will work.

This is a total mess, so sorry and good luck. You really need the fastq and gfa files, and a place to write everything

Assuming we have the [test data](https://github.com/Vini2/reneo/tree/develop/reneo/test_data) in a directory called `reneo`:

```
reneo/assemblyGraph.gfa
reneo/reads/A13-04-182-06_TAGCTT_R1.fastq.gz
reneo/reads/A13-04-182-06_TAGCTT_R2.fastq.gz
reneo/reads/A13-12-250-06_GGCTAC_R1.fastq.gz
reneo/reads/A13-12-250-06_GGCTAC_R2.fastq.gz
```

Then this should work in a slurm job (see reneo.slurm)

```
module load singularity/4.1.0-slurm

singularity exec --bind /scratch/pawsey1018/edwa0468/tmp/conda:/conda,/home/edwa0468/Projects/reneo/reneo:/reneo,/home/edwa0468/gurobi.lic:/opt/gurobi/gurobi.lic \ 
	sif/reneo_v0.4.0_387f995e969d.sif reneo run --input /reneo/assemblyGraph.gfa --reads /reneo/reads  --output /reneo/reneo_out --threads 32 
```

**NOTE:**: If you get an error:

```
ValueError: numpy.dtype size changed, may indicate binary incompatibility. Expected 96 from C header, got 88 from PyObject
```

This is your local conda installation, _not_ the singularity file. Activate your conda environment (see the error file for which conda environment it is) and then
install an earlier version of numpy:

```
python -m pip  install numpy==1.26.4
```



