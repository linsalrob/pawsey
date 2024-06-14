# use koverage on an assembly and reads

import os
import sys


usage=f"{sys.arg[0] <assembly.fasta> <fastq directory>}"

ASSEMBLY=sys.arg[1]
READDIR=sys.arg[2]
OUTPUT='koverage'

if not os.path.exists(ASSEMBLY):
    print(f"{ASSEMBLY} does not exist.\n{usage}", file=sys.stderr)
    sys.exit(1)

if not os.path.exists(READDIR):
    print(f"{READDIR} does not exist.\n{usage}", file=sys.stderr)
    sys.exit(1)



rule all:
    input:
        OUTPUT

rule koverage:
    input:
		ass=ASSEMBLY,
        reads=READDIR
    output:
        directory(OUTPUT)
    conda: "koverage.yaml"
    resources:
        mem_mb=32000,
        cpus=12
    params: 
        odir = OUTPUT
    shell:
        """
        mkdir -p {params.odir};
        koverage run --reads {input.reads} --ref {input.ass}
        """

