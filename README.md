# User accounts, adding people, allocations, and acacia keys

Check https://portal.pawsey.org.au

Keys are stored in rclone.conf already (~/.config/rclone/rclone.conf)

# Conda

Install conda in

```
/software/projects/$PAWSEY_PROJECT/$USER/miniconda3
```

and then set your package directory to be on `/scratch/`

```
conda config --add pkgs_dirs /scratch/$PAWSEY_PROJECT/$USER/miniconda3/pkg_dir
```

## Create a temporary conda installation. 

This will get deleted after (at most) 30 days, but is good if you want to install 
something to test. 


```
TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP  python=3.12
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP
```

Alternatively, make a TMP miniconda:
```
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/megahit  'python>=3.12'
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/megahit
```

# Partitions


More information [Pawsey partitions](https://pawsey.atlassian.net/wiki/spaces/US/pages/51929058/Running+Jobs+on+Setonix)

work partition (316 nodes, 128 cores per node)
- Default partition, used for regular compute jobs
- 230 GB available memory per node, which is 1.8 GB per core
- max time 24 hours
debug partition (8 nodes, 128 cores per node)
- Intended for short interactive jobs
- Use for benchmarking, testing, debugging, profiling and development
copy partition (8 nodes, 32 cores per node)
- Use for data transfers to/from Setonix
- 89 GB available memory per node, which is approximately 2.78 GB per core 
highmem partition (8 nodes, 128 cores per node)
- Use for large memory workflows that require more than 230 GB RAM per node
- Supports up to 980 GB of available memory per node, which is 7.65 GB per core
long partition (8 nodes, 128 cores per node)
- Use for jobs that require wall times between 24 and 96 hours

# Data Moving

Use  data-mover.pawsey.org.au  to put data onto/off of pawsey

# acacia

Bucket names must be unique.
Bucket names must all be lowercase
Names probably have to be unique across all S3, so databases doesn't work!

e.g. 
  VALID: rclone mkdir pawsey1018:fame 
INVALID: rclone mkdir pawsey1018:FAME

# Account Balance

You can check the status of your accounts with

pawseyAccountBalance -mygroups

(note the -storage option does not appear to work)

# Disk quotas

You can check the disk quotas for either your PROJECT or USER using these two command:

```
lfs quota -g $PAWSEY_PROJECT -h /software
lfs quota -u $USER -h /software
```

In particular, pay attention to the number of files, usually limited to 100,000


# Conda clean

Using 

```
conda clean -af
```

wil clean up some of the conda cache files.


# squeue_format

By default, things like array jobs don't show up. Set the $SQUEUE_FORMAT env variable to set the columns to show


# create a mamba (conda) environment in scratch. Note you probably have to delete this since you've named it!
mamba env create --file atavide_lite.yaml --prefix /scratch/pawsey1018/edwa0468/software/miniconda3/atavide_lite

Here is the TMP version
TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP  python=3.12
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP

# rclone

Make sure that you add `--local-no-set-modtime` to any rclone command.

Ordinarily, `rclone` syncs the local timestamp so that it is the same as the remote file. However, if you download a file later, that time stamp will be >30 days old and the file will be deleted. 
e.g.

```
rclone copy --local-no-set-modtime A18:fame/CF/JessCarlsonJones/WorldWideCF/fasta/fasta_subsampled fasta_subsampled
```

# installing node and nvm

I currently have these installed on `/scratch` with a symlink from `$HOME/.nvm` to the directory on `/scratch`, so they sometimes disappear!

Delete and redownload nvm:

```
cd ~/.nvm
rm -rf alias versions test
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install node
```

