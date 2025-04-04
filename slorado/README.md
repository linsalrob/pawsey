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
VERSION=v0.2.0-XXX
wget "https://github.com/BonsonW/slorado/releases/download/$VERSION/slorado-$VERSION-x86_64-rocm-linux-binaries.tar.gz"
tar xvf slorado-$VERSION-x86_64-rocm-linux-binaries.tar.gz
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


## Run slorado
