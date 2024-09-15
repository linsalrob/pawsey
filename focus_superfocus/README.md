# Process a bunch of metagenomes

We have a lot of metagenomics data, and this script will process that for us through focus and superfocus

# Step 1. Download unsorted fasta files (because we don't need the quality scores)

make a file of `run_ids.txt` and then `sbatch --array=1-$(wc -l run_ids.txt | awk '{print $1}'):1 download_fasta.slurm` (or something like that ... maybe in two steps?)

# Step 2. Run focus and superfocus on those




