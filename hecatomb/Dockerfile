# Use the official miniconda3 image as a base
FROM continuumio/miniconda3

# Set environment variables to avoid interactive prompts and set paths
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV PATH /opt/conda/bin:$PATH

# Update the package list and install necessary packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    bzip2 \
    libglib2.0-0 \
    libxext6 \
    libsm6 \
    libxrender1 \
    git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Mamba using Conda
RUN conda install -y mamba -c conda-forge
RUN conda config --set channel_priority strict

RUN pip install "numpy<2.0"

ARG HECATOMB_VERSION=1.3.2
RUN mamba install -n base -y -c conda-forge -c bioconda -c defaults hecatomb=${HECATOMB_VERSION} ;
RUN conda clean --all --yes
RUN mkdir -p /hecatomb

RUN ln -s /opt/micromamba/lib/python3.12/site-packages/reneo/workflow/conda/ /conda
RUN hecatomb install

RUN mkdir -p /hecatomb/fastq
RUN printf "@seq1/1\nATGCAT\n+\nZZZZZZ\n" > /hecatomb/fastq/tmp_R1.fastq
RUN printf "@seq1/2\nATGCAT\n+\nZZZZZZ\n" > /hecatomb/fastq/tmp_R2.fastq

# RUN snakemake -s /opt/conda/lib/python3.12/site-packages/hecatomb/snakemake/workflow/Hecatomb.smk --use-conda --conda-prefix /opt/conda/lib/python3.12/site-packages/hecatomb/snakemake/conda --conda-create-envs-only --cores 2  --configfile hecatomb.out/hecatomb.config.yaml --workflow-profile hecatomb.out/hecatomb.profile --reads /hecatomb/fastq/

RUN hecatomb run --use-conda --conda-prefix /opt/conda/lib/python3.12/site-packages/hecatomb/snakemake/conda --conda-create-envs-only --cores 2  --configfile hecatomb.out/hecatomb.config.yaml --workflow-profile hecatomb.out/hecatomb.profile --reads /hecatomb/fastq/

RUN rm -rf /hecatomb/fastq/


# snakemake -s /opt/conda/lib/python3.12/site-packages/hecatomb/snakemake/workflow/Hecatomb.smk --configfile hecatomb.out/hecatomb.config.yaml --cores 32 --use-conda --conda-prefix /opt/conda/lib/python3.12/site-packages/hecatomb/snakemake/conda --conda-create-envs-only --workflow-profile hecatomb.out/hecatomb.profile
# 
