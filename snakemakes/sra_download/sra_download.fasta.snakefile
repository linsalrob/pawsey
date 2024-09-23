
# Use fasterq dump to download a whole bunch of fasta files from the SRA
# You also need the yaml file that includes sra-tools as a dependency

import os


SRR=[]
with open("SRR_Acc_List.txt", "r") as srrfile:
    for l in srrfile:
        SRR.append(l.strip())

rule all:
    input:
        expand(os.path.join("fasta", "{srr}"), srr=SRR)

rule download_fasta:
    output:
        odir = directory(os.path.join("fasta", "{srr}"))
    conda: "sra_download.yaml"
    params: srr="{srr}"
    resources:
        mem_mb=32000,
        cpus=8
    shell:
        """
        mkdir -p {output.odir} &&
        fasterq-dump --outdir {output.odir} --split-3 --fasta-unsorted --threads 8 {params.srr} && \
                find {output.odir} -type f -exec gzip {{}} \;
        """
