#!/bin/bash
# Re-derive the concordance table from dnadiff .report files.
# dnadiff writes "AlignedBases  3479553(100.00%)  3479457(100.00%)", so the
# count and the percentage must be split rather than stripped together.
d=$1
{
printf "query\tref_len\tqry_len\tavg_identity\tref_aligned_pct\tqry_aligned_pct\trelocations\ttranslocations\tinversions\n"
for rep in "$d"/*_vs_ref.report; do
    q=$(basename "$rep" _vs_ref.report)
    awk -v q="$q" '
      /^TotalBases/    {rl=$2; ql=$3}
      /^AlignedBases/  {ra=$2; qa=$3}
      /^AvgIdentity/   {if(id=="") id=$2}
      /^Relocations/   {if(rel=="") rel=$2}
      /^Translocations/{if(tr=="")  tr=$2}
      /^Inversions/    {if(iv=="")  iv=$2}
      END{
        match(ra,/\(([0-9.]+)%\)/,a); match(qa,/\(([0-9.]+)%\)/,b);
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", q, rl, ql, id, a[1], b[1], rel, tr, iv
      }' "$rep"
done
} > "$d/concordance_summary.tsv"
column -t -s$'\t' "$d/concordance_summary.tsv"
