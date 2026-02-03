#!/usr/bin/env bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=extract_genomes
#SBATCH --time=1-0
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=64GB
#SBATCH -o %x-%j.out
#SBATCH -e %x-%j.err

set -euo pipefail
trap 's=$?; echo "ERROR: ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2; exit $s' ERR

IN_ROOT="/scratch/pawsey1018/gbouras/archaea/baktfold_compare_out"
OUT_DIR="genomes"

mkdir -p "$OUT_DIR"

# Optional: avoid accidental overwrites (uncomment to enable)
# set -o noclobber

echo "Starting extraction at $(date)"
echo "Input:  $IN_ROOT"
echo "Output: $OUT_DIR"
echo

find "$IN_ROOT" -type f -name '*.tar.gz' -size +1M -print0 |
while IFS= read -r -d '' archive; do
  genome="$(basename "$archive" .tar.gz)"

  # Identify candidate .gbff files in the archive.
  # Prefer ones containing the genome name, but fall back to any .gbff.
  mapfile -t matches < <(tar -tzf "$archive" | awk -v g="$genome" '
    $0 ~ /\.gbff(\.gz)?$/ && index($0, g) { print; found=1 }
    END { if (!found) exit 1 }
  ' || true)

  if (( ${#matches[@]} == 0 )); then
    mapfile -t matches < <(tar -tzf "$archive" | awk '$0 ~ /\.gbff(\.gz)?$/ { print }' || true)
  fi

  if (( ${#matches[@]} == 0 )); then
    echo "WARN: no .gbff found in archive: $archive" >&2
    continue
  fi

  # If multiple matches, choose the first deterministically and warn.
  gbff_path="${matches[0]}"
  if (( ${#matches[@]} > 1 )); then
    echo "WARN: multiple .gbff matches in $archive; using: $gbff_path" >&2
  fi

  out="$OUT_DIR/${genome}.gbff.gz"
  tmp="$out.$SLURM_JOB_ID.tmp"

  echo "Extracting: $(basename "$archive") -> $out"
  # Stream extract the member file and ensure output is gzipped.
  # If the member is already .gz, this will double-compress; optionally handle that (see note below).
  tar -xzf "$archive" --to-stdout "$gbff_path" | gzip -c > "$tmp"
  mv -f "$tmp" "$out"
done

echo
echo "Done at $(date)"
