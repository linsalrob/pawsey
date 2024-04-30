import os
import sys




PEPTIDES="/home/edwa0468/Projects/ToddNorton/peptides.txt"

rule all:
    input:
        expand("chvd.{translation}.pep.fasta.gz", 
               translation=[1, 10, 11, 12, 13, 14, 15, 16, 2, 21, 22, 23, 24, 25, 26, 27, 28, 29, 3, 30, 31, 4, 5, 6, 9])
rule download_CHVD:
    output:
        "CHVD_virus_sequences_v1.1.fasta.gz"
    shell:
        """
        curl -LO "https://zenodo.org/records/4776317/files/CHVD_virus_sequences_v1.1.tar.gz?download=1"
        """

rule find_peptides:
    input:
        "CHVD_virus_sequences_v1.1.fasta.gz"
    output:
        "chvd.{translation}.pep.fasta.gz"
    params:
        tr = "{translation}",
        pep = PEPTIDES
    resources:
        mem_mb=64000,
        cpus=24
    shell:
        """
        /home/edwa0468/software/bin/get_orfs -t {params.tr} -f {input} | grep -B 1 -Ff {params.pep} -  > {output} || [ "$?" -eq 1 ]
        """
        
