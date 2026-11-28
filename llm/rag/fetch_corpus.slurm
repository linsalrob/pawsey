#!/bin/bash
# Download the corpus listed in llm/rag/corpus/$RAG_CORPUS.manifest.tsv (JATS
# full text from Europe PMC) on the copy partition and split it into passages.
#   sbatch --account="$PAWSEY_PROJECT" --export=ALL llm/rag/fetch_corpus.slurm
#SBATCH --job-name=llm-rag-corpus
#SBATCH --partition=copy
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=%x-%j.out
set -euo pipefail
HERE=${LLM_DIR:-${SLURM_SUBMIT_DIR:-.}/llm}
# shellcheck source=../versions.env
source "$HERE/versions.env"
module load cray-python
manifest=$HERE/rag/corpus/$RAG_CORPUS.manifest.tsv
mkdir -p "$RAG_ROOT"
cp "$manifest" "$RAG_ROOT/manifest.tsv"
python3 "$HERE/rag/corpus.py" fetch "$manifest" "$RAG_ROOT/xml"
python3 "$HERE/rag/corpus.py" chunk "$manifest" "$RAG_ROOT/xml" "$RAG_ROOT/passages.jsonl"
du -sh "$RAG_ROOT/xml"
