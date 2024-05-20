
# Use fasterq dump to download a whole bunch of fastq files from the SRA
# You also need the yaml file that includes sra-tools as a dependency

import os


SRR=[]
with open("SRR_Acc_List.txt", "r") as srrfile:
    for l in srrfile:
        SRR.append(l.strip())

rule all:
    input:
        expand(os.path.join("fastq", "{srr}"), srr=SRR)

rule download_fastq:
    output:
        odir = directory(os.path.join("fastq", "{srr}"))
    conda: "sra_download.yaml"
    params: srr="{srr}"
    shell:
        """
        mkdir -p {output.odir} &&
        fasterq-dump --outdir {output.odir} {params.srr}
        """
