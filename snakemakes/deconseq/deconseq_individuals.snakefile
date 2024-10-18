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


SAMPLES,EXTENSIONS = glob_wildcards(os.path.join(readdir, '{sample}.fasta{extentions}'))

if not EXTENSIONS:
    sys.stderr.write("""
        FATAL: We could not parse the sequence file names.
        """)
    sys.exit()
# we just get the generic extension. This is changed in Step 1


file_extension = EXTENSIONS[0]


rule all:
    input:
        expand([
            os.path.join(outdir, "{sample}_" + hostname + '.mapped.' + outfmt + ".gz"),
            os.path.join(outdir, '{sample}_singletons_' + hostname + '.mapped.' + outfmt + ".gz"),
            os.path.join(outdir, '{sample}_singletons_' + hostname + '.unmapped.' + outfmt + ".gz"),
            os.path.join(outdir, "{sample}_" + hostname + '.unmapped.' + outfmt + ".gz"),
        ], sample=SAMPLES)
    

rule minimap:
    input:
        r1 = os.path.join(readdir, '{sample}.fasta' + file_extension),
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
            {input.r1} | \
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
        os.path.join(outdir, "{sample}_" + hostname + '.mapped.' + outfmt + ".gz")
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt} -F 3588 -G 12 -f 65 {input.bam} | gzip -c > {output}"

rule single_reads_map_to_ref:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, '{sample}_singletons_' + hostname + '.mapped.' + outfmt + ".gz")
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt}  -F 5 {input.bam} | gzip -c > {output}"

rule R1_unmapped:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, "{sample}_" + hostname + '.unmapped.' + outfmt + ".gz")
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt} -F 3584 -f 77  {input.bam} | gzip -c > {output}"


rule single_reads_unmapped:
    input:
        bam = os.path.join(outdir, '{sample}.' + hostname + '.bam'),
        bai = os.path.join(outdir, '{sample}.' + hostname + '.bam.bai')
    output:
        os.path.join(outdir, '{sample}_singletons_' + hostname + '.unmapped.' + outfmt + ".gz")
    conda:
        "deconseq.yaml"
    shell:
        "samtools {outfmt}  -f 4 -F 1  {input.bam} | gzip -c > {output}"
