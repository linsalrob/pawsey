# Process a bunch of metagenomes

We have a lot of metagenomics data, and this script will process that for us through focus and superfocus

# Step 1. Download unsorted fasta files (because we don't need the quality scores)

Before you do this, download the non-sudo tar archive of the [Ubuntu sra-toolkit](https://github.com/ncbi/sra-tools/wiki/01.-Downloading-SRA-Toolkit) and extract that archive. Then you need to set the path to `fasterq-dump` in this slurm script.

make a file of `run_ids.txt` and then `sbatch --array=1-$(wc -l run_ids.txt | awk '{print $1}'):1 download_fasta.slurm` (or something like that ... maybe in two steps?)

# Step 2. Run focus and superfocus on those

You need to build the [focus](../focus/) and [superfocus](../superfocus) `.sif` images. See those directories for instructions on how to do that. You also need the superfocus mmseqs2 DB_95 data.

This runs focus and superfocus on the fasta directory
```
sbatch process_metagenomes.slurm fasta
```

## Step 2b. Teams data

We also have some data in teams, and this will run focus and superfocus on that data:

```
process_teams_metagenomes.slurm
```



