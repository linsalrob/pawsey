# Slurm Workflows for genome_entropy

This repository contains Slurm job scripts used to execute and manage large-scale *genome_entropy* analyses on high-performance computing clusters.

The *genome_entropy* project (https://github.com/linsalrob/genome_entropy) provides a computational framework for quantifying information content across multiple biological representations derived from genomic sequences. By integrating DNA sequences, open reading frames, translated proteins, and structure-informed encodings (e.g., 3Di), *genome_entropy* yields a unified information-theoretic view of sequence complexity and organisation across molecular layers.

## Purpose

The scripts in this repository are designed to:

- Orchestrate high-throughput *genome_entropy* computations across many genomes or metagenomes.
- Standardise resource allocation (CPU, memory, time) and environment setup for reproducible batch execution.
- Enable large-scale benchmarking, parameter sweeps, and dataset-wide processing on Slurm-based clusters.
- Log, checkpoint, and monitor job progress using cluster scheduling best practices.

## Overview

Each script targets a specific computational pattern, including:

- **Batch processing of samples**  
  Submit a collection of genomes/metagenomes for entropy analysis in parallel or array mode.

- **Dependency-aware workflows**  
  Run multi-stage analyses (e.g., sequence preprocessing → ORF extraction → entropy computation → summary aggregation) with Slurm job dependencies.

- **Resource profiles**  
  Scripts pre-tune Slurm directives (e.g., `#SBATCH --cpus-per-task`, memory, GPUs if used) for common cluster environments.

## Requirements

Before running these scripts on your cluster, ensure:

- A working installation of the *genome_entropy* package (refer to its README for installation instructions).
- A compatible Python environment with dependencies installed (virtualenv, conda, or module-based environments as appropriate).
- Access to a Slurm scheduler on your HPC cluster.
- Input data (FASTA, genome assemblies, metadata, etc.) organised per the expected directory structure documented below.

