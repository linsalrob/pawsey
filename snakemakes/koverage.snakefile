# use koverage on an assembly and reads

import os
import sys
import itertools



fasta = ["Bc01", "Bc02", "Bc03", "Bc05", "Bc06", "Bc07", "Bc08", "Bc09", "Bc10", "Bc11", "Bc13", "Bc14", "Bc15", "Bc16"]
ena_all = ["ERP024424", "ERP104038", "ERP104039", "ERP104041", "ERP104076", "ERP104174", "ERP104197", "ERP104200", "ERP104202", "ERP104204", "ERP104205", "ERP104206", "ERP104207", "ERP104208", "ERP104237", "ERP105558", "ERP105879", "ERP125908", "ERP127759", "ERP128046", "ERP129176"]
ena = ["ERP104207", "ERP105558", "ERP104204", "ERP104197", "ERP104200", "ERP104038", "ERP104041", "ERP104039", "ERP104174", "ERP104208", "ERP024424", "ERP104202", "ERP104205", "ERP104076"]



DATA = {}
for c in itertools.product(fasta, ena):
    ASSEMBLY=f"fasta/{c[0]}.fasta"
    READDIR=f"ena_small/{c[1]}/fastq"
    OUTPUT=f"{c[0]}_{c[1]}"
    DATA[OUTPUT] = (ASSEMBLY, READDIR)



rule all:
    input:
        expand("{faf}_{ebi}", faf=fasta, ebi=ena)

rule koverage:
    input:
        ass = lambda wildcards: f"fasta/{wildcards.faf}.fasta",
        reads = lambda wildcards: f"ena_small/{wildcards.ebi}/fastq"
    output:
        odir = directory("_".join(["{faf}", "{ebi}"]))
    conda: "koverage.yaml"
    resources:
        mem_mb=32000,
        cpus=12
    shell:
        """
        mkdir -p {output.odir};
        export ASSEMBLY={input.ass};
        export READS={input.reads};
        koverage run --reads {input.reads} --ref {input.ass} --output {output.odir} \
                --threads {resources.cpus} 
        """

