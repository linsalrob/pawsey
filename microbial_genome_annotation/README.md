# Microbial genome assembly and annotation pipeline

No, its not a pipeline, its a bunch of slurm scripts, but I'm sure you can deal with that!

Starting with Nanopore fastq files we:

1. Assemble using [autocycler](https://github.com/rrwick/Autocycler)
2. Rearrange using [dnaapler](https://github.com/gbouras13/dnaapler)
3. Annotate using [bakta](https://github.com/oschwengers/bakta)
4. Improve using [baktfold](https://github.com/gbouras13/baktfold)


Each of the four steps has two slurm scripts, an `STEP_install.slurm` which will install the software and download any required databases, and a `STEP_run.slurm` that will run the code.

The `_install.slurm` scripts generally require no options, but for most of them you will need to get the TMP name and use it in the `_run.slurm` script. The `_run.slurm` scripts generally take two options, the name of the input file (fastq file, fasta file, json file, etc.) and the name of the output directory. 

## 1. Assemble using [autocycler](https://github.com/rrwick/Autocycler)

Requires the input fastq file from nanopore reads, and an output directory name:

e.g.

```
sbatch ~/GitHubs/pawsey/microbial_genome_annotation/autocycler_run.slurm AB5075_AdeB.fastq AB5075_AdeB
```


## 2. Rearrange using [dnaapler](https://github.com/gbouras13/dnaapler)




## 3. Annotate using [bakta](https://github.com/oschwengers/bakta)




## 4. Improve using [baktfold](https://github.com/gbouras13/baktfold)







