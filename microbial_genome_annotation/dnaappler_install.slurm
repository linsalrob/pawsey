#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=dnaappler_install
#SBATCH --time=0-1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16GB
#SBATCH --ntasks=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

eval "$(conda shell.bash hook)"

# dnaapler gets its own environment: in microbial_annotations, plassembler holds it
# at 0.8.1, and 0.8.1 does not rotate contigs with integer names (e.g. Autocycler's
# "1"); fixed in dnaapler v1.0.1 (gbouras13/dnaapler PR #88). Forcing >=1.0.1 into
# microbial_annotations would downgrade canu to 1.4 and plassembler to 0.1.5.
ENV_DIR=/scratch/pawsey1018/edwa0468/software/miniconda3/dnaapler
if [[ -e "$ENV_DIR" || -L "$ENV_DIR" ]]; then
	mamba env remove --yes --prefix "$ENV_DIR" || rm -rf -- "$ENV_DIR"
fi
mamba create -y --prefix="$ENV_DIR" -c conda-forge -c bioconda "dnaapler>=1.0.1"
echo -e "dnaapler installed in $ENV_DIR\n\nmamba activate $ENV_DIR"
"$ENV_DIR/bin/dnaapler" --version



