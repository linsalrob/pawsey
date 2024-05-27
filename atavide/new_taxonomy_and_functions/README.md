# Generate a better taxonomy information for atavide

We're going to use [taxonkit](https://bioinf.shenwei.me/taxonkit/) since they have put the work in to make it work

# taxonkit

## data

You need to download the NCBI data. You should then set the $TAXONKIT_DB environment 

taxonkit only requires names.dmp, nodes.dmp, delnodes.dmp and merged.dmp

## set an environment variable

```
DATE=`date +%Y%m`
TAXONKIT_DB=~/Databases/NCBI/taxonomy/taxonomy.$DATE
mkdir -p $TAXONKIT_DB
cp names.dmp nodes.dmp delnodes.dmp merged.dmp $TAXONKIT_DB
```

# snakemake

You need snakemake version 7 to run this. Don't use version 8 at the moment, because it breaks a lot of things.

If you have a directory `mmseqs`, and in that directory you have a bunch of samples, each one is a directory, and in those you have the output from `mmseqs easy-taxonomy` like this:

```
mmseqs/
    SAGCFN_22_01149_S3/
        SAGCFN_22_01149_S3_lca.tsv.gz    
    SAGCFN_22_01175_S20/
        SAGCFN_22_01175_S20_lca.tsv.gz  
    SAGCFN_23_00214_S1/
        SAGCFN_23_00214_S1_lca.tsv.gz
```

Then you can run the command:

```
snakemake --profile slurm -s ~/GitHubs/pawsey/atavide/new_taxonomy/taxonomy.smk
```

and it should make the `*.lca.taxonomy.tsv.gz` files for you

# Long read taxonomy (minion and contigs)

We have a new approach to calculate the long read taxonomy.

For minion sequences our approach is:

1. Dorado – basecalling
2. Filtlong – QC/QA – removes low quality (<5%) and v. short reads (<1,000bp)
  - (check for adapter sequences with fastp?)
3. Host removal with minimap2 and samtools filters
4. ORF calling – direct on fastq – >30 amino acids  faa.gz
  - multiple orfs per sequence (contig/long sequence)
5. mmseqs2 easy taxonomy on amino acids
6. Add taxonomy labels using the same code as above
7. Summarise taxonomy per contig (or long sequence)
8. Make one table each for kingdom, phylum, class, order, family, genus, species

Steps 1-3 are done elsewhere. The code [here](contig_taxonony_by_orf.smk) handles steps 4-8 in a snakemake script. The command to run it is 

```
snakemake -s contig_taxonony_by_orf.smk --profile slurm
```

This needs a directory called `fastq` with the `.fastq.gz` output files from host-removal. The first step will generate protein `.fasta` files directly from that `.fastq` file - no intermediate required!

# Outputs

## taxonomy

The `taxonomy` directory contains the following files:
- kingdom.tsv.gz
- phylum.tsv.gz
- class.tsv.gz
- order.tsv.gz
- family.tsv.gz
- genus.tsv.gz
- species.tsv.gz

These files contain the fraction of reads that map to each phylogentic level * 1,000,000 (so if you add up the row sums, it adds upto a million).


## subsystems

We summarise the counts per subsystem in three different ways. Again, we multiply the numbers by a million just so we are working with numbers that are easier to comprehend!

### Normalised to all reads that have a subsystem

This is the file you almost certainly want to use, as it will be most comparable between samples. We count how many reads match _any_ subsystem, and divide by that number. This will provide an estimate of the fraction of each metabolism that occurs in your sample using a normalisation that is comparable between samples.

### Normalised to all reads that have a match to anything

We have a lot of sequences that match a protein, but that protein is not in a subsystem. This metric normalises to the number of reads in your sample that match anything at all. It will be skewed if you have a contamination in your sample (e.g. of a eukaryote) for which we don't have a lot of subsytem data.

### Not normalised (raw counts)

You should not use this for direct comparisons, but we provide it in case you wish to renormalise the data, eg. by diving this by the total number of reads in the sample.

### Going down an mmseqs rabbit hole...

`mmseqs easy-taxonomy` reports two key files:
1. `_tophit_aln.gz` has the top alignment(s) for the sequence. If there are equally valid alignments, both will be reported
2. `_tophit_report.gz` has the protein that matches and the number of reads that match to it.

However, a read can match to >1 protein, because equal-best top hits are included. Therefore, to summarise the number of subsystems, we need to count the reads from `_tophit_aln.gz` and report either (a) a random hit, (b) a hit with a subsystem match, or (c) a hit without a subsystem match.




# UniRef50 vs. UniRef100

We have had some discussion about using [UniRef50 vs UniRef100](https://www.uniprot.org/help/uniref). The main issues are size, speed, and completeness

## Size

The `mmseqs` formatted `UniRef50` is 31G, while the `mmseqs` formatted `UniRef100` is 228G. (This formatting includes the taxonomy information). Therefore, the computation will take ~10x longer on UniRef100 vs. UniRef50.

228G    UniRef100.20240520
(miniconda3) edwa0468@setonix-05:mmseqs [1008]$ du -hs UniRef50.20240520/
31G     UniRef50.20240520/




