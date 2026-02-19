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

### 1b. Optional. Rename the contigs.

We want to rename the contigs all at once, so we can do it for every file:

```
AC=(AB5075_AdeB AB5075_AdeC102 AB5075_AdeC189 AB5075_AdeH124 AB5075_AdeH134 AB5075_AdeJ AB5075_AdeK164 AB5075_AdeK188 AB5075_AdeN AB5075_FadL ATCC17978_AdeB ATCC17978_AdeJ ATCC17978_AdeN ATCC17978_FadL)
for F in ${AC[@]}; do PREFIX=$F perl -pe 's/^>/>$ENV{PREFIX}_/' $F/autocycler_out/consensus_assembly.fasta > ${F}_consensus_assembly.fasta; done
```

_Note:_ Important: there is no `;` between `PREFIX=$F` and `perl -pe` otherwise `PREFIX` is undefined.
_Note2:_ Make sure you run `bakta` with the `--keep-contig-headers` option otherwise this work will be lost!

## 2. Rearrange using [dnaapler](https://github.com/gbouras13/dnaapler)

```
sbatch /home/edwa0468/GitHubs/pawsey/microbial_genome_annotation/dnaappler_run.slurm AB5075_AdeB_consensus_assembly.fasta AB5075_AdeB_dnaappler
```

## 3. Annotate using [bakta](https://github.com/oschwengers/bakta)

```
BAKTA=$(sbatch --parsable /home/edwa0468/GitHubs/pawsey/microbial_genome_annotation/bakta_run.slurm  AB5075_AdeB_dnaappler/dnaapler_reoriented.fasta AB5075_AdeB_bakta);
```


## 4. Improve using [baktfold](https://github.com/gbouras13/baktfold)


```
sbatch --dependency="afterok:$BAKTA" /home/edwa0468/GitHubs/pawsey/microbial_genome_annotation/baktfold_run.slurm AB5075_AdeB_bakta/dnaapler_reoriented.json AB5075_AdeB_baktfold; done
```



