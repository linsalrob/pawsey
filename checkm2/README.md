# CheckM2 Installation and Usage Notes

We installed it from the git repo and used mamba to create the environment from the provided `checkm2.yml` file.

```
git clone --recursive https://github.com/chklovski/checkm2.git && cd checkm2
mamba env create --prefix=/home/edwa0468/Projects/CF/crAss/MixedAssemblies/cross_assembly/checkm2/checkm2_env -f checkm2.yml
mamba activate /scratch/pawsey1018/edwa0468/CF/crAss/MixedAssemblies/cross_assembly/checkm2/checkm2_env
```


Then install the databases
```
checkm2 database --download --path /home/edwa0468/Databases/checkm2
```

Finally, we run checkm2 on our bins. Note the slurm script needs the location of the checkm2 binary as an argument. However,
the conda environment is currently hardcoded in the slurm script, sigh.

```
sbatch ~/GitHubs/pawsey/checkm2/checkm2.slurm ../bins ../bins_checkm2 bin/checkm2
```
