#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=install_qc_env
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Separate environment for assembly QC so that microbial_annotations, which
# holds the working autocycler/bakta installation, is not disturbed.

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

ENV_DIR="/scratch/${PAWSEY_PROJECT}/${USER}/software/miniconda3/assembly_qc"
eval "$(mamba shell hook --shell bash)"
[[ -e "$ENV_DIR" ]] && { mamba env remove --yes --prefix "$ENV_DIR" || rm -rf -- "$ENV_DIR"; }

mamba create -y --prefix="$ENV_DIR" -c conda-forge -c bioconda \
	mummer4 sourmash bcftools samtools minimap2 seqkit

mamba activate "$ENV_DIR"
for x in dnadiff nucmer sourmash bcftools samtools minimap2 seqkit; do
	printf "%-10s " "$x"; command -v "$x" >/dev/null && echo OK || echo MISSING
done
echo "assembly_qc installed in $ENV_DIR"
