#!/usr/bin/env python3
"""Assemble the per-sample parts of a snapshot into one table plus totals.

Usage: collect_snapshot.py <snapshot dir>

Columns are read from the seqkit header by NAME, never by position, because
`seqkit stats -a` emits N50 and N50_num before the quality columns and picking
indices by eye silently mislabels them.
"""
import os, glob, os, sys

S = sys.argv[1].rstrip("/")
def human(n):
    for unit, div in (("G", 1024**3), ("M", 1024**2), ("K", 1024)):
        if n >= div: return f"{n/div:.2f}{unit}"
    return f"{n}B"

rows = []
for st in sorted(glob.glob(f"{S}/per_sample/*.seqstats.tsv")):
    sample = os.path.basename(st).replace(".seqstats.tsv", "")
    lines = open(st).read().splitlines()
    if len(lines) < 2: continue
    d = dict(zip(lines[0].split("\t"), lines[1].split("\t")))
    nf = open(f"{S}/per_sample/{sample}.files.count").read().split("\t")[1].strip()
    by = int(open(f"{S}/per_sample/{sample}.du.tsv").read().split("\t")[1])
    rows.append([sample, nf, by, human(by), d["num_seqs"], d["sum_len"], d["min_len"],
                 d["avg_len"], d["max_len"], d["N50"], d["Q20(%)"], d["Q30(%)"],
                 d["AvgQual"], d["GC(%)"]])

cols = ["sample","files","bytes","size","reads","bases","min_len","avg_len",
        "max_len","N50","Q20","Q30","avg_qual","GC"]
with open(f"{S}/snapshot.tsv", "w") as fh:
    fh.write("\t".join(cols) + "\n")
    for r in rows: fh.write("\t".join(map(str, r)) + "\n")

# file-level manifest, so an added or removed chunk is identifiable by name
with open(f"{S}/file_manifest.tsv", "w") as fh:
    for p in sorted(glob.glob(f"{S}/per_sample/*.files.tsv")):
        fh.write(open(p).read())

tr = sum(int(r[4]) for r in rows); tb = sum(int(r[5]) for r in rows)
ty = sum(r[2] for r in rows);      tf = sum(int(r[1]) for r in rows)
with open(f"{S}/TOTALS.txt", "w") as fh:
    fh.write(f"snapshot\t{os.path.basename(S)}\nsamples\t{len(rows)}\nfiles\t{tf}\n"
             f"reads\t{tr}\nbases\t{tb}\nbytes\t{ty}\nsize\t{human(ty)}\n")
print(open(f"{S}/TOTALS.txt").read())
print(f"written {S}/snapshot.tsv and {S}/file_manifest.tsv")
