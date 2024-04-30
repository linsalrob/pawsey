import os
import sys

GFA="PhablesMGNify:General/data/gfa/ERP104047/ERZ1740178.gfa.gz"

os.makedirs("gfa", exist_ok=True)
os.makedirs("fasta", exist_ok=True)
os.makedirs("orfs", exist_ok=True)
os.makedirs("peps", exist_ok=True)

PEPTIDES="/home/edwa0468/Projects/ToddNorton/peptides.txt"
PROJECTS = []
SAMPLES  = []
with open("gut_gfa.txt", "r") as f:
    for l in f:
        p = l.strip().split("/")
        PROJECTS.append(p[3])
        SAMPLES.append(p[4].replace('.gfa.gz', ''))


rule all:
    input:
        expand("peps/{project}/{assembly}.peptides", zip, project=PROJECTS, 
               assembly=SAMPLES)

rule download_gfa:
    output:
        temporary("gfa/{project}/{assembly}.gfa.gz")
    conda:
        "get_peptides.yaml"
    params:
        ass="{assembly}",
        pro="{project}"
    shell:
        """
        mkdir --parents gfa/{params.pro} &&
        rclone copy PhablesMGNify:General/data/gfa/{params.pro}/{params.ass}.gfa.gz gfa/{params.pro}/
        """


rule gfa_to_fasta:
    input:
        gfa = "gfa/{project}/{assembly}.gfa.gz"
    output:
        fasta = temporary("fasta/{project}/{assembly}.fasta")
    params:
        ass="{assembly}",
        pro="{project}"
    shell:
        """
        mkdir --parents fasta/{params.pro} &&
        zcat {input.gfa} | awk -v id={params.ass} '/^S/{{print \">\"id\"_\"$2\"\\n\"$3}}' > {output.fasta}
        """

rule compress_fasta:
    input:
        fasta = "fasta/{project}/{assembly}.fasta"
    output:
        fasta = "fasta/{project}/{assembly}.fasta.gz"
    shell:
        """
        gzip {input.fasta}
        """

rule translate_fasta:
    input:
        fasta = "fasta/{project}/{assembly}.fasta.gz"
    output:
        orfs = "orfs/{project}/{assembly}.orfs.gz"
    params:
        ass="{assembly}",
        pro="{project}"
    resources:
        mem_mb=32000,
        cpus=12
    shell:
        """
        mkdir --parents orfs/{params.pro} &&
        /home/edwa0468/software/bin/get_orfs -f {input.fasta} | gzip -c > {output.orfs}
        """
 
rule get_peptides:
    input:
        orfs = "orfs/{project}/{assembly}.orfs.gz",
        pep = PEPTIDES
    output:
        pep = "peps/{project}/{assembly}.peptides"
    params:
        ass="{assembly}",
        pro="{project}"
    shell:
        """
        mkdir --parents peps/{params.pro} &&
        zgrep -B 1 -Ff {input.pep} {input.orfs} > {output.pep} || [ "$?" -eq 1 ]
        """


