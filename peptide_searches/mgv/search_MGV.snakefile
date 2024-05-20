import os
import sys




PEPTIDES="/home/edwa0468/Projects/ToddNorton/peptides.txt"

rule all:
    input:
        expand("mgv.{translation}.pep.fasta.gz", 
               translation=[1, 10, 11, 12, 13, 14, 15, 16, 2, 21, 22, 23, 24, 25, 26, 27, 28, 29, 3, 30, 31, 4, 5, 6, 9])

rule find_peptides:
    input:
        "MGV_v1.0_2021_07_08/mgv_contigs.fna"
    output:
        "mgv.{translation}.pep.fasta.gz"
    params:
        tr = "{translation}",
        pep = PEPTIDES
    resources:
        mem_mb=64000,
        cpus=24
    shell:
        """
        /home/edwa0468/software/bin/get_orfs -t {params.tr} -f {input} | grep -B 1 -Ff {params.pep} - > {output} || [ "$?" -eq 1 ] 
        """
        
