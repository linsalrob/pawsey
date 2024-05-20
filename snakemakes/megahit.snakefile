# use megahit to assemble a whole bunch of samples.

import os

# we need a list of samples (in fastq/) to assemble

SRR=[]
with open("SRR_Acc_List.txt", "r") as srrfile:
    for l in srrfile:
        SRR.append(l.strip())

os.makedirs("megahit", exist_ok=True)

rule all:
    input:
        expand(os.path.join("megahit", "{srr}", "{srr}.graph.gfa"), srr=SRR)

rule assemble_fastq:
    input:
        r1=os.path.join("fastq", "{srr}", "{srr}_1.fastq.gz"),
        r2=os.path.join("fastq", "{srr}", "{srr}_2.fastq.gz")
    output:
        fasta = os.path.join("megahit", "{srr}", "final.contigs.fa")
    conda: "megahit.yaml"
    resources:
        mem_mb=32000,
        cpus=12
    params: 
        srr="{srr}",
        odir = directory(os.path.join("megahit", "{srr}")),
    shell:
        """
        rmdir {params.odir};
        megahit -1 {input.r1} -2 {input.r2} -o {params.odir} -t 12
        """

rule megahit_to_fastg:
    input:
        fasta = os.path.join("megahit", "{srr}", "final.contigs.fa")
    output:
        fastg = os.path.join("megahit", "{srr}", "{srr}.graph.fastg")
    conda: "megahit.yaml"
    params: 
        srr="{srr}",
    shell:
        """
        megahit_toolkit contig2fastg 119 {input.fasta} > {output.fastg}
        """

rule fastg2gfa:
    input:
        fastg = os.path.join("megahit", "{srr}", "{srr}.graph.fastg")
    output:
        gfa = os.path.join("megahit", "{srr}", "{srr}.graph.gfa")
    shell:
        """
        ~/bin/fastg2gfa {input.fastg} > {output.gfa}
        """




