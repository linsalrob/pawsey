# Run some stuff with mmseqs

Steps:

1. Create a temporary conda environment for mmseqs so we can blow it away later
2. Download the appropriate mmseqs database to ~/scratch/
3. Run the comparison with mmseqs


Lets go!

1. Create a temporary conda environment for mmseqs so we can blow it away later

```
TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP  'python>=3.12'
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP
mamba install -y mmseqs2
MMSEQS=/scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/$TMP/bin/mmseqs
```

2. Make a directory and download the databases

This code checks for `mmseqs` but you can also provide the location as an argument.

```
JOB=$(sbatch --parsable download_gtdb.slurm $MMSEQS)
```

3. Run the comparison with mmseqs


```
sbatch --dependency='afterok:$JOB' mmseqs_easy_taxonomy.slurm $MMSEQS /scratch/$PAWSEY_PROJECT/$USER/fasta/R1.fasta.gz  /scratch/$PAWSEY_PROJECT/$USER/fasta/R2.fasta.gz
```
