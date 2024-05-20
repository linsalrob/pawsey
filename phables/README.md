# Load the singularity module and create a new image

```
module load singularity/3.11.4-slurm
mkdir sif
singularity pull --dir sif docker://linsalrob/phables:v0.6_gogo
```

Now, you need to link the directories so that everything will work.

This is a total mess, so sorry and good luck. You really need the fastq and gfa files, and a place to write everything

Assuming we have:

```
phables/$SRR
phables/$SRR/$SRR.graph.gfa
phables/$SRR/fastq/$SRR_1.fastq.gz
phables/$SRR/fastq/$SRR_2.fastq.gz
```

Then this should work in a slurm job (see phables.slurm)

```
module load singularity/3.11.4-slurm
singularity exec --bind /scratch/pawsey1018/edwa0468/tmp/conda:/conda,$PWD/phables/$SRR:/phables,$HOME/gurobi.lic:/opt/gurobi/gurobi.lic sif/phables_v0.6_gogo.sif \
        phables run --input /phables/$SRR.graph.gfa --reads /phables/fastq/ --output /phables/phables --threads 32 --prefix $SRR --mincov 1
```
