# Microbial genome assembly and annotation pipeline

No, its not a pipeline, its a bunch of slurm scripts, but I'm sure you can deal with that!

Starting with Nanopore fastq files we:

1. Assemble using [autocycler](https://github.com/rrwick/Autocycler), or [plassembler](https://github.com/gbouras13/plassembler) if the sample is a plasmid prep rather than a whole isolate
2. Rearrange using [dnaapler](https://github.com/gbouras13/dnaapler)
3. Annotate using [bakta](https://github.com/oschwengers/bakta)
4. Improve using [baktfold](https://github.com/gbouras13/baktfold)
5. Optionally, find prophages using [PhiSpy](https://github.com/linsalrob/PhiSpy)
6. Optionally, find antiviral defence systems using [PADLOC](https://github.com/padlocbio/padloc) and [DefenseFinder](https://github.com/mdmparis/defense-finder)


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

### 1c. Optional. Plasmid preps: assemble with [plassembler](https://github.com/gbouras13/plassembler) instead.

Autocycler expects a whole bacterial isolate. If a barcode is a plasmid prep, use
`plassembler_run.slurm` instead. It takes the reads, an output directory, and
optionally the approximate lower-bound chromosome length. Pass `none` when the
reads contain no chromosome at all, which runs plassembler with `--no_chromosome`:

```
sbatch ~/GitHubs/pawsey/microbial_genome_annotation/plassembler_run.slurm barcode16.fastq.gz barcode16_plassembler none
```

For a normal isolate where you do expect a chromosome, give its approximate
lower-bound length instead (the plassembler default is 1000000):

```
sbatch ~/GitHubs/pawsey/microbial_genome_annotation/plassembler_run.slurm AB5075_AdeB.fastq AB5075_AdeB_plassembler 2000000
```

The assembled plasmids are written to `<output>/plassembler_out/plassembler_plasmids.fasta`,
with a summary of the copy numbers and PLSDB hits in `plassembler_summary.tsv`.

_Note:_ plassembler is already in `autocycler.yaml`, so it is installed as part of
the `microbial_annotations` environment. `plassembler_install.slurm` only needs to be
run if that environment is missing, or to reinstall the PLSDB database -- which does
happen, because `/scratch` gets purged.

## 5. Optional. Find prophages using [PhiSpy](https://github.com/linsalrob/PhiSpy)

PhiSpy needs gene calls, not just sequence, so run it on the GenBank file bakta
writes rather than on an assembly:

```
sbatch /home/edwa0468/GitHubs/pawsey/microbial_genome_annotation/phispy_run.slurm AB5075_AdeB_bakta/dnaapler_reoriented.gbff AB5075_AdeB_phispy
```

PhiSpy ships around 140 training sets and recommends the most closely related
one. List them with `PhiSpy.py --list short` and pass one as a third argument:

```
sbatch /home/edwa0468/GitHubs/pawsey/microbial_genome_annotation/phispy_run.slurm AB5075_AdeB_bakta/dnaapler_reoriented.gbff AB5075_AdeB_phispy data/trainSet_Saureus.txt
```

The default generic set is built from 48 genomes. It is the right choice when
nothing closely related is available, and also when counts need to be
comparable across genomes of different species -- an organism-specific set can
change the number of regions called, so it is worth running both and reporting
the difference rather than picking one silently.

_Note:_ prophage coordinates are relative to the sequence PhiSpy was given. If
that came through dnaapler, the origin has been rotated, so those coordinates
do not line up with the pre-dnaapler assembly. Map a feature across if you need
to compare.

## 6. Optional. Find antiviral defence systems

Both tools take bakta's output and both are worth running: they use different
model sets and different naming, and they do not find the same things.

### [PADLOC](https://github.com/padlocbio/padloc)

Needs the proteins AND the feature coordinates, because defence systems are
called from gene content and synteny together:

```
sbatch ~/GitHubs/pawsey/microbial_genome_annotation/padloc_run.slurm \
    AB5075_AdeB_bakta/dnaapler_reoriented.faa \
    AB5075_AdeB_bakta/dnaapler_reoriented.gff3 \
    AB5075_AdeB_padloc
```

The .faa and .gff3 must come from the same bakta run or the coordinates will
not match the proteins. Passing a nucleotide FASTA instead makes PADLOC call
genes itself with prodigal, which throws away the bakta annotation.

_Note:_ the run script rewrites the GFF before handing it over, for two
reasons. bakta appends the genome sequence after a `##FASTA` line, which PADLOC
parses as tens of thousands of malformed feature rows. More importantly, PADLOC
replaces a CDS's `ID` with its `Name` whenever the CDS has a `pseudo`
attribute — correct for RefSeq and GenBank GFFs, where `Name` is an
identifier, but bakta puts the **product description** there. The substitution
turns a locus tag into something like `DNA 3'-5' helicase`, which then fails to
match the protein in the .faa and PADLOC aborts with
`N protein sequence IDs are missing from GFF file`. It only fires when a
pseudogene happens to hit a defence HMM, so across a set of genomes it looks
sporadic. The script strips the `pseudo` attribute so the locus tag survives.

### [DefenseFinder](https://github.com/mdmparis/defense-finder)

Takes the protein FASTA alone:

```
sbatch ~/GitHubs/pawsey/microbial_genome_annotation/defensefinder_run.slurm \
    AB5075_AdeB_bakta/dnaapler_reoriented.faa AB5075_AdeB_defensefinder
```

DefenseFinder infers gene adjacency from the order of records in the FASTA, so
do not sort or shuffle the .faa — bakta writes it in coordinate order, which is
what is wanted.

### Comparing the two

They report different numbers and use different names for the same systems
(`RM_type_I` against `RM_Type_I`, `AbiO-Nhi_family` against `AbiO`,
`cas_type_III-A` against `Cas`). There is no shared controlled vocabulary, so
any cross-tool agreement count is approximate and should be described as such.

### Databases

`padloc_install.slurm` and `defensefinder_install.slurm` put their databases in
`~/Databases/padloc` and `~/Databases/defensefinder`, outside the conda
environments, so rebuilding an environment does not mean re-downloading. PADLOC
ignores `--data` during `--db-update` and always installs into the package
directory, so the install script downloads and then relocates, leaving a
symlink behind.

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



