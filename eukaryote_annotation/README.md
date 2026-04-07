# Eukaryote Genome Annotation

Yuck, I can't believe I'm even thinking about this. Its going to be a mess, but here goes.

## Base annotations

We're going to use [funannoate](https://github.com/nextgenusfs/funannotate) from Jason Stajich and co. 

<small>Sad that even [Jason](https://pubmed.ncbi.nlm.nih.gov/12368254/) uses Python.</small>

## 0. Singularity

Convert the docker image to a singularity image

(Instructions lost in the mists of time ... only you can recreate them!)


## 1. Set up funannoatate

This downloads the databases and can be done in parallel with the clean step

```bash
sbatch ~/GitHubs/pawsey/eukaryote_annotation/funannotate_setup.slurm
```

## 2. Clean the contigs.

We compare from the shortest contig to N<sup>50</sup> against the longer contigs to remove any duplicates.

```bash
sbatch ~/GitHubs/pawsey/eukaryote_annotation/funannotate_clean.slurm <CONTIGS>
```


