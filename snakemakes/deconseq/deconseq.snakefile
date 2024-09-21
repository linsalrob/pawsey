############################################################
#                                                          #
# A snakefile to remove host contamination.                #
#                                                          #
# We have several versions of contamination removal        #
# this uses minimap2                                       #
#                                                          #
# For more information see this site:                      #
# https://edwards.flinders.edu.au/command-line-deconseq/   #
#                                                          #
# You will need a config file with the directory of the    #
# reads and the path to the host. See deconseq_config.yaml #
# for an example.                                          #
#                                                          #
# snakemake --configfile deconseq.yaml -s deconseq.snakefile --profile slurm
#                                                          #
# Rob Edwards, 2020                                        #
#                                                          #
############################################################

import os

readdir = config['readdir']
hostfile = config['hostfile']
hostname = config['hostname']
outdir = config['outdir']
outfmt = config['outfmt']


if not os.path.exists(readdir):
    sys.stderr.write(f"ERROR: Could not find the read directory {readdir}\n")
    sys.stderr.write("Please confirm the location and edit the snakefile\n")
    sys.exit()


if not os.path.exists(hostfile):
    sys.stderr.write(f"ERROR: Could not find {hostfile}\n")
    sys.stderr.write(f" - You may need to edit `hostfile` in the snakefile\n")
    sys.exit()


SAMPLES,EXTENSIONS = glob_wildcards(os.path.join(readdir, '{sample}_R1{extentions}'))

if not EXTENSIONS:
    sys.stderr.write("""
        FATAL: We could not parse the sequence file names.
        We are expecting {sample}_R1{extension}, and so your files
        should contain the characters '_R1' in the fwd reads
        and '_R2' in the rev reads
        """)
    sys.exit()
# we just get the generic extension. This is changed in Step 1

file_extension = EXTENSIONS[0]
# a convenience so we don't need to use '{sample}_R1' all the time
PATTERN_R1 = '{sample}_R1'
PATTERN_R2 = '{sample}_R2'

rule all:
    input:
        expand([
            os.path.join(outdir, PATTERN_R1 + "_" + hostname + '.mapped.' + outfmt),
            os.path.join(outdir, PATTERN_R2 + "_" + hostname + '.mapped.' + outfmt),
            os.path.join(outdir, '{sample}_singletons_' + hostname + '.mapped.' + outfmt),
            os.path.join(outdir, PATTERN_R1 + "_" + hostname + '.unmapped.' + outfmt),
            os.path.join(outdir, PATTERN_R2 + "_" + hostname + '.unmapped.' + outfmt),
            os.path.join(outdir, '{sample}_singletons_' + hostname + '.unmapped.' + outfmt)
        ], sample=SAMPLES)
    

rule minimap:
    input:
        r1 = os.path.join(readdir, '{sample}_R1' + file_extension),
        r2 = os.path.join(readdir, '{sample}_R2' + file_extension),
    output:
        temporary(os.path.join(outdir, '{sample}.' + hostname + '.bam'))
    params:
        host = hostfile
    resources:
        mem_mb=64000,
        cpus=16
    conda:
        "deconseq.yaml"
    shell:
        """
        minimap2 -t {resources.cpus} --split-prefix=tmp$$ -a -xsr {params.host} \
            {input.r1} {input.r2} | \
            samtools view -bh | samtools sort -o {output}
        """

rule index_bam:
    input:
        os.path.join(outdir, '{sample}.' + hostname + '.bam')
    output:
        temporary(os.path.join(outdir, '{sample}.' + hostname + '.bam.bai'))
    conda:
        "deconseq.yaml"
    shell:
        "samtools index {input}"

rule R1_reads_map_to_ref:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, PATTERN_R1 + "_" + hostname + '.mapped.' + outfmt)
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt} -F 3588 -G 12 -f 65 {input.bam} | gzip -c > {output}"

rule R2_reads_map_to_ref:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, PATTERN_R2 + "_" + hostname + '.mapped.' + outfmt)
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt} -F 3588 -G 12 -f 129 {input.bam} | gzip -c > {output}"

rule single_reads_map_to_ref:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, '{sample}_singletons_' + hostname + '.mapped.' + outfmt)
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt}  -F 5 {input.bam} | gzip -c > {output}"

rule R1_unmapped:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, PATTERN_R1 + "_" + hostname + '.unmapped.' + outfmt)
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt} -F 3584 -f 77  {input.bam} | gzip -c > {output}"

rule R2_unmapped:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, PATTERN_R2 + "_" + hostname + '.unmapped.' + outfmt)
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt} -F 3584 -f 141 {input.bam} | gzip -c > {output}"

rule single_reads_unmapped:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, '{sample}_singletons_' + hostname + '.unmapped.' + outfmt)
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt}  -f 4 -F 1  {input.bam} | gzip -c > {output}"
