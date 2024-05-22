################################################################
#                                                              #
# ORF-based functions.                                         #
#                                                              #
# NOTE: This is designed to be used with minion reads          #
# therefore, we don't have R1/R2, just fastq files             #
#                                                              #
# (c) Rob Edwards                                              #
#                                                              #
# This is also based on "new taxonomy"                         #
#                                                              #
################################################################

import os
import sys


READDIR = 'fastq'
MMSEQS = 'mmseqs'
SCRATCH = "/scratch/pawsey1018/edwa0468"

# A Snakemake regular expression matching the forward mate FASTQ files.
# the comma after SAMPLES is important!
FQSAMPLES, = glob_wildcards(os.path.join(READDIR, '{sample}.fastq.gz'))
if len(FQSAMPLES) == 0:
    sys.stderr.write(f"We did not find any fastq files in {SAMPLES}. Is this the right read dir?\n")
    sys.exit(0)


# include the required rules
include: "rules/add_functions.smk"


# make some output directories
os.makedirs(MMSEQS, exist_ok=True)

rule all_functions:
    input:
        expand(os.path.join(MMSEQS, "{sample}", "{sample}_tophit_report.gz"), sample=FQSAMPLES),
        expand(os.path.join(MMSEQS, "{sample}", "{sample}_tophit_report_subsystems.gz"), sample=FQSAMPLES),

