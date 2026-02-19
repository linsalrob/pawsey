#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=autocycler
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err
#SBATCH --mem=128G

# Note: this is a slurmified version of the autocycler code from https://github.com/rrwick/Autocycler/tree/main/pipelines/Automated_Autocycler_Bash_script_by_Ryan_Wick
#

# location of the autocycler installation
TMP=5b87b46d65df
# location of the PLASSEMBLER Databases
export PLASSEMBLER_DB=$HOME/Databases/plassembler/

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

if [[ $# != 2 ]]; then
	echo "$0 <nanopore reads> <output directory> <read type (ont-10)>" >&2;
	exit 2;
fi

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP


# This script is a wrapper for running a fully-automated Autocycler assembly.


# Copyright 2025 Ryan Wick (rrwick@gmail.com)
# modifications 2026 by Rob Edwards
# Licensed under the GNU General Public License v3.
# See https://www.gnu.org/licenses/gpl-3.0.html.

reads=$1
output=$2
TMPDIR=$(mktemp -dp /scratch/$PAWSEY_ACCOUNT/$USER)
echo "Temporary files in $TMPDIR"


# Get arguments.
threads=32               # threads per job
jobs=4                  # number of simultaneous jobs
read_type=${3:-ont_r10}  # read type (default = ont_r10)

# Input assembly jobs that exceed this time limit will be killed
max_time="8h"

# the default for this is 25, but some of my assemblies have 45
MAXCONTIGS=100

# Validate input parameters
if [[ -z "$reads" || -z "$threads" || -z "$jobs" ]]; then
    echo "Usage: $0 <read_fastq> <outputdir> [read_type]" 1>&2
    exit 1
fi
if [[ ! -f "$reads" ]]; then
    echo "Error: Input file '$reads' does not exist." 1>&2
    exit 1
fi
if (( threads > 128 )); then threads=128; fi  # Flye won't work with more than 128 threads
case $read_type in
    ont_r9|ont_r10|pacbio_clr|pacbio_hifi) ;;
    *) echo "Error: read_type must be ont_r9, ont_r10, pacbio_clr or pacbio_hifi" 1>&2; exit 1 ;;
esac

genome_size=$(autocycler helper genome_size --reads "$reads" --threads "$threads")

# Step 1: subsample the long-read set into multiple files
# NOTE: RAE has reduced --min_read_depth from the default 25 to 10 here because one sample has fewer reads.
autocycler subsample --reads "$reads" --out_dir $TMPDIR/subsampled_reads --genome_size "$genome_size" --min_read_depth 10

# Step 2: assemble each subsampled file
mkdir -p $TMPDIR/assemblies
rm -f $TMPDIR/assemblies/jobs.txt
for assembler in raven myloasm miniasm flye metamdbg necat nextdenovo plassembler canu; do
    for i in 01 02 03 04; do
        echo "autocycler helper $assembler --reads $TMPDIR/subsampled_reads/sample_$i.fastq --out_prefix $TMPDIR/assemblies/${assembler}_$i --threads $threads --genome_size $genome_size --read_type $read_type" --min_depth_rel 0.1 >> $TMPDIR/assemblies/jobs.txt
    done
done
trap - ERR
set +e
nice -n 19 parallel --jobs "$jobs" --joblog $TMPDIR/assemblies/joblog.tsv --results $TMPDIR/assemblies/logs --timeout "$max_time" < $TMPDIR/assemblies/jobs.txt
set -e
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# Give circular contigs from Plassembler extra clustering weight
shopt -s nullglob
for f in $TMPDIR/assemblies/plassembler*.fasta; do
    sed -i 's/circular=True/circular=True Autocycler_cluster_weight=3/' "$f"
done

# Give contigs from Canu and Flye extra consensus weight
for f in $TMPDIR/assemblies/canu*.fasta assemblies/flye*.fasta; do
    sed -i 's/^>.*$/& Autocycler_consensus_weight=2/' "$f"
done
shopt -u nullglob

# Remove the subsampled reads to save space
rm $TMPDIR/subsampled_reads/*.fastq

# Step 3: compress the input assemblies into a unitig graph
# RAE: Increase the max number of contigs, because one or two are being a pain
autocycler compress -i $TMPDIR/assemblies -a $TMPDIR/autocycler_out --max_contigs $MAXCONTIGS

# Step 4: cluster the input contigs into putative genomic sequences
# RAE: Increase the max number of contigs, because one or two are being a pain
autocycler cluster -a $TMPDIR/autocycler_out --max_contigs $MAXCONTIGS

# Steps 5 and 6: trim and resolve each QC-pass cluster
for c in $TMPDIR/autocycler_out/clustering/qc_pass/cluster_*; do
    autocycler trim -c "$c" 
    autocycler resolve -c "$c" 
done

# Step 7: combine resolved clusters into a final assembly
autocycler combine -a $TMPDIR/autocycler_out -i $TMPDIR/autocycler_out/clustering/qc_pass/cluster_*/5_final.gfa 

## END

mkdir -p `dirname $2`

rsync -av $TMPDIR/ $2
rm -rf $TMPDIR

