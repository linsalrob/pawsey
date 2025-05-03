# Nanopore basecalling on Pawsey

These notes largely come from [Bonson Wong](https://github.com/BonsonW/slorado/blob/main/docs/pawsey.md) and you should use that site. If I've done it right, I will make comments and suggestions if needed!

Make a directory on `/scratch` and install [blue-crab](https://github.com/Psy-Fer/blue-crab) and `slorado`.

# Installation

```
mkdir ~/scratch/slorado
cd ~/scratch/slorado
```


### blue-crab

```
python3 -m venv ./blue-crab-venv
source ./blue-crab-venv/bin/activate
python3 -m pip install --upgrade pip
pip install blue-crab
blue-crab --help
```

### slorado

Checkout the code. Definitely confirm on Bonson's site whether this is the latest version!

```
VERSION=v0.3.0-beta
GPU=rocm
wget "https://github.com/BonsonW/slorado/releases/download/$VERSION/slorado-$VERSION-x86_64-$GPU-linux-binaries.tar.xz"
tar xvf slorado-$VERSION-x86_64-$GPU-linux-binaries.tar.xz
cd slorado-$VERSION
bin/slorado --help
```

# Running

## Run blue-crab

Use this slurm script to run blue-crab


```
#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=bluecrab
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128GB
#SBATCH -o bluecrab-%j.out
#SBATCH -e bluecrab-%j.err
                                                                                                                                                                                                                 set -euo pipefail
# change this to where you installed blue-crab
source /home/edwa0468/scratch_1018/slorado/blue-crab-venv/bin/activate

# change this to the appropriate data directory
BASE=/home/edwa0468/scratch_1018/CF/Promethion/CF_PromethION_matched_samples/CF_PromethION_matched_samples_Run2/20250314_1541_P2S-02700-B_PBA71146_20fca30d

blue-crab p2s --out-dir $BASE/blow5/ --compress zlib --threads 16 $BASE/pod5
```

## Slow5Stats

I recommend, at this point, running [slow5tools stats](https://github.com/hasindu2008/slow5tools) on all the `blow5` files. This will tell you (a) if the files converted OK, and (b) how many reads there are per file. Then, when slorado is done, it is easy to cross check the number of sequences in the fastq file and blow5 files.

## Run slorado

### Install slorado

```
VERSION=v0.3.0-beta
GPU=rocm
wget "https://github.com/BonsonW/slorado/releases/download/$VERSION/slorado-$VERSION-x86_64-$GPU-linux-binaries.tar.xz"
tar xvf slorado-$VERSION-x86_64-$GPU-linux-binaries.tar.xz
```

Then run it using the `slorado.slurm` script.

Note, when I was converting ~100 files the `gpu-dev` could do about 1/2 at time before maxing out (time limit is 4 hours), so I just ran it twice on the `gpu-dev` queue. The regular GPU queue was taking about 3 days to get a job started.


## Demultiplexing

If you have used barcodes, there are a couple of ways that you can separate the fastq files into separate files. The cutadapt.slurm script uses [cutadapt](https://cutadapt.readthedocs.io/en/stable/) to split the fastq files. This needs the barcodes as a fasta file.

If you are going to use this, make a temporary conda installation with cutadapt:

```
TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP  cutadapt
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP
echo -e "Add this line at the start of cutadapt.slurm:\nTMP=$TMP"
```

Make sure you change the value of TMP in the `cutadapt.slurm` file.

Once you have created the output files, you will get a _lot_ of separate barcode files. Here is one way to join them into unique barcode files:

```
mkdir split_barcodes
for i in $(seq 1 9); do cat demuxed_reads/*_RB0$i.fastq >> split_barcodes/RB0$i.fastq; done
for i in $(seq 10 96); do cat demuxed_reads/*_RB$i.fastq >> split_barcodes/RB$i.fastq; done
```


For [dorado](https://github.com/nanoporetech/dorado), start by getting the appropriate binary from the [Installation section](https://github.com/nanoporetech/dorado?tab=readme-ov-file#installation).

`Dorado` needs the name of the barcoding kit. Top Top: the name probably replaces a period for an underscore, just to be annoying. e.g. The ONT product `SQK-RBK114.24` is called `SQK-RBK114-24`. You can find a list of all possible kits using the help.

```
dorado demux --help
```

## f5c for aligning squiggles

```
VERSION=v1.5
wget "https://github.com/hasindu2008/f5c/releases/download/$VERSION/f5c-$VERSION-binaries.tar.gz" && tar xvf f5c-$VERSION-binaries.tar.gz && cd f5c-$VERSION/
```

### Comparison data set

In this data set we only used barcodes 1-13. Cutadapt was given all 96 possible barcodes, while dorado was only given barcodes 1-24, so the comparison is not fair, but you can see that lots of the unassigned reads are potentially off-by-one errors for other barcodes

selection | catadapt | dorado | catadapt_sup | dorado_sup
--- | --- | --- | --- | ---
barcodes 1-13 | 1516136 | 1355273 | 1563055 | 1314039
barcodes 14-24 | 22755 | 69 | 17146 | 67
barcodes 24-96 | 286768 | 4 | 258312 | 3
Unclassified | 187739 | 657493 | 175238 | 698729
Total Reads | 2012835 | 2012835 | 2012835 | 2012835
Percent assigned | 75.32 | 67.33 | 77.65 | 65.28



