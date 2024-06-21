# Use a base image with a shell and basic tools installed
FROM ubuntu:20.04
FROM gurobi/optimizer:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl build-essential wget doxygen gnupg gnupg2 apt-transport-https software-properties-common \
    bzip2 git vim gfortran libtool python3-venv ninja-build python3-pip libnuma-dev python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install micromamba
RUN curl -L https://micromamba.snakepit.net/api/micromamba/linux-64/latest | tar -xvj -C /usr/local/bin/ --strip-components=1 bin/micromamba

# Set the environment variable for micromamba
ENV MAMBA_ROOT_PREFIX=/opt/micromamba
RUN micromamba shell init -s bash -p $MAMBA_ROOT_PREFIX
ENV PATH=$MAMBA_ROOT_PREFIX/bin:$PATH


ARG RENEO_VERSION=0.4.0
RUN micromamba install -n base -y -c conda-forge -c anaconda -c bioconda -c defaults reneo=${RENEO_VERSION} python ;

RUN micromamba clean --all --yes
RUN mkdir -p /reneo /opt/gurobi

RUN ln -s /opt/micromamba/lib/python3.10/site-packages/reneo/workflow/conda/ /conda
RUN reneo install


