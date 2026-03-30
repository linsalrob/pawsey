# Getting colabfold running on pawsey

These instructions are from George, and you should check with him.

The container is from Sarah and is here: https://quay.io/repository/sarahbeecroft9/colabfold?tab=tags

NOTE: Use singularity 3.11 because singularity 4 sucks

```bash
COLABDIR=/scratch/$PAWSEY_PROJECT/$USER/colabfold/
mkdir -p $COLABDIR
cd $COLABDIR
module load pawseyenv/2023.08
module load singularity/3.11.4-slurm
singularity pull colabfold_rocm6_cpuTF.sif   docker://quay.io/sarahbeecroft9/colabfold:rocm6_cpuTF
```

Then, we can run one search

sbatch --account=${PAWSEY_PROJECT}-gpu ~/GitHubs/pawsey/colabfold/colab_search.slurm proteins/JDOEVDKM_CDS_0075.fasta  structures//JDOEVDKM_CDS_0075


A note from George:

```
DB_DIR=/scratch/references/colabfold_jun2024/database/
colabfold_search --threads $THREADS ${input}.fasta  $DB_DIR  $MSA_OUTDIR
```

