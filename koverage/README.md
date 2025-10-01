# Using Koverage on Pawsey

1. Create a temporary directory for your conda environment

```
TMP=$(for i in {1..12}; do printf "%x" $((RANDOM % 16)); done)
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/$TMP  python=3.12
mamba activate /scratch/pawsey1018/edwa0468/software/miniconda3/$TMP
```

2. Install koverage

```
pip install koverage
```
