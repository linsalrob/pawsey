FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND="noninteractive"

ARG LIBFABRIC_VERSION=1.21.0
ARG UBUNTU_RELEASE=noble

# Install required packages and dependencies
RUN   apt -y update \
      && apt -y install build-essential wget doxygen gnupg gnupg2 curl apt-transport-https software-properties-common  \
      git vim gfortran libtool python3-venv ninja-build python3-pip \
      libnuma-dev python3-dev slurm-client \
      && apt -y remove --purge --auto-remove cmake \
      && wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null\
      | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null \
      && apt-add-repository -y "deb https://apt.kitware.com/ubuntu/ ${UBUNTU_RELEASE} main" \
      && apt -y update

# Build and install libfabric
RUN (if [ -e /tmp/build ]; then rm -rf /tmp/build; fi;) \
      && mkdir -p /tmp/build \
      && cd /tmp/build \
      && wget https://github.com/ofiwg/libfabric/archive/refs/tags/v${LIBFABRIC_VERSION}.tar.gz \
      && tar xf v${LIBFABRIC_VERSION}.tar.gz \
      && cd libfabric-${LIBFABRIC_VERSION} \
      && ./autogen.sh \
      && ./configure \
      && make -j 16 \
      && make install

#
# Install miniforge
#
RUN set -eux ; \
  curl -LO https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh ; \
  bash ./Miniforge3-* -b -p /opt/miniforge3 -s ; \
  rm -rf ./Miniforge3-*

# create a directory so we can mount the remote /usr/bin e.g. for local slurm commands
RUN mkdir /usr/remotebin
ENV PATH /opt/miniforge3/bin:$PATH:/usr/remotebin
#
# Install conda environment
#

RUN pip install "numpy<2.0"

ARG HECATOMB_VERSION=1.3.2
RUN mamba install --freeze-installed -n base -y -c conda-forge -c bioconda -c defaults hecatomb=${HECATOMB_VERSION} ;
RUN mkdir -p /hecatomb

ENV PATH /opt/miniforge3/bin:$PATH
RUN conda clean -af -y

RUN conda config --set channel_priority strict

ARG SITE_PACKAGES=default_value

# each RUN is in its own container, and so we need to share this variable!
RUN SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])") && echo "SITE_PACKAGES=${SITE_PACKAGES}" > /tmp/site_packages
RUN . /tmp/site_packages && echo "\033[92mSITE_PACKAGES dotted is ${SITE_PACKAGES}\033[0m"

RUN . /tmp/site_packages && ln -s ${SITE_PACKAGES}/hecatomb/snakemake/conda/ /conda
RUN hecatomb install

RUN mkdir -p /hecatomb/fastq
RUN printf "@seq1/1\nATGCAT\n+\nZZZZZZ\n" > /hecatomb/fastq/tmp_R1.fastq
RUN printf "@seq1/2\nATGCAT\n+\nZZZZZZ\n" > /hecatomb/fastq/tmp_R2.fastq

RUN . /tmp/site_packages && hecatomb run --use-conda --conda-create-envs-only --cores 2  --configfile hecatomb.out/hecatomb.config.yaml --workflow-profile hecatomb.out/hecatomb.profile --reads /hecatomb/fastq/

RUN rm -rf /hecatomb/fastq/  /tmp/site_packages

