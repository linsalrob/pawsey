# Using FOCUS with singularity

We have made a focus dockerfile that we can create into a .sif image.

The current tag is d95c4fb1ae57

# Load the singularity module and create a new image


NOTE: There is (currently) an issue with singularity 4.1.0. If it persists, here is how to load a previous image:

```
module load pawseyenv/2023.08
module load singularity/3.11.4-slurm
```

Otherwise, this will make a focus `.sif`

```
export TAG=d95c4fb1ae57
module load singularity/4.1.0-slurm
mkdir sif tmp
# remember that singularity needs the full path (not a relative path, like tmp)
export SINGULARITY_TMPDIR=$PWD/tmp/
singularity pull --dir sif docker://linsalrob/focus:v1.8.0_${TAG}
```

Now, you need to link the directories so that everything will work.

Assuming you have  

/home/edwa0468/Projects/focus
/home/edwa0468/Projects/focus/fasta/

Then this should work in a slurm job (see focus.slurm)

```
module load singularity/4.1.0-slurm

singularity exec --bind /home/edwa0468/Projects/focus:/focus \ 
	sif/focus:v1.8.0_${TAG} focus -q /focus/fasta -o /focus/focus -k 7 
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



