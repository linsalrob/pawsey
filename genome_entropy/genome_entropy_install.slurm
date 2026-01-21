#!/bin/bash
#SBATCH --account=pawsey1018-gpu
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu-dev
#SBATCH --job-name=ge_install
#SBATCH --time=0-1
#SBATCH --ntasks=1
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

###### NOTES ######
#
# This script creates a virtual environment for genome_entropy on a GPU node at Pawsey.
# There are two (or 3?) things that you need to get working together.
#
# First, check which rocm versions we have:
# 
# module avail rocm
# (currently the latest is rocm/6.4.1)
#
# Second, check whether there is a pytorch for that version at https://download.pytorch.org/whl/torch/
# This curl/regexp will find all the python 3.12 versions - change the cp312 to change that
#
# curl -s https://download.pytorch.org/whl/torch/ | grep -oP '(?<=">)[^">]*rocm6.4.*cp312[^<]*'
#
# Now you can also see the specific versions of pytorch you need.
#
# Here are the steps:
# First, load the right module.
# Second, install the right pytorch version.
# Third, we install genome_entropy, but with no dependencies, otherwise it will remove our rocm pytorch
# and install the NVIDIA one.
# Fourth, we install the dependencies for genome_entropy, except for torch.
# Finally, we use pip check to list any missing dependencies.


set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# ---- 1) Get the right module here!
module load rocm/6.4.1

# ---- 2) Create and load the virtual environment 
VENV_DIR="/scratch/pawsey1018/edwa0468/software/pip/genome_entropy"
if [[ -e "$VENV_DIR" ]]; then 
	rm -rf "$VENV_DIR"
fi

mkdir -p "$VENV_DIR"
python -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Upgrade packaging tooling
pip install --upgrade pip setuptools wheel

# ---- 3) Install pytorch and then genome_entropy
# The pytorch module already provides torch/ROCm; avoid pip installing another torch build.
# This requires pip > 23.2
pip --version
pip install --index-url https://download.pytorch.org/whl/rocm6.4 "torch == 2.9.1" torchvision torchaudio
pip install --no-deps  genome_entropy "transformers>=4.30.0"  "pygenetic_code>=0.20.0"  "typer>=0.9.0"  "tqdm>=4.65.0"  "protobuf>=6.33.1"  "sentencepiece>=0.2.1"  "biopython>=1.80"
pip install "huggingface-hub<1.0,>=0.34.0" packaging pyyaml regex requests safetensors tokenizers click rich shellingham

echo "Running pip check"
pip check

echo "Sane?"
# ---- Sanity checks ----
python - <<'PY'
import sys
print("Python:", sys.version)
try:
    import torch
    print("PyTorch:", torch.__version__)
    print("CUDA available? (ROCm builds return True here):", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("Device 0:", torch.cuda.get_device_name(0))
except Exception as e:
    print("Torch check failed:", e)

try:
    import genome_entropy
    print("genome_entropy:", getattr(genome_entropy, "__version__", "unknown"))
except Exception as e:
    print("genome_entropy import failed:", e)
PY

echo "Done. Virtual env at: $VENV_DIR"
eval "$(conda shell.bash hook)"
