#!/usr/bin/env python3
"""Build a curated Autocycler input set from the concordant assemblies.

Keeps the concordant complete or near-complete chromosome contigs, drops the
fragmented chromosome pieces the other inputs contributed, and preserves the
contigs that already passed QC.

Only assemblies containing a concordant chromosome are retained, so that
Autocycler's automatic --min_assemblies threshold is computed over an input set
in which the chromosome really is near-universal. This is deliberately NOT the
same as lowering --min_assemblies globally, which also admits fragmented and
contaminant clusters.

Original FASTA headers are preserved, since they carry the
Autocycler_consensus_weight and cluster_weight annotations that the pipeline
scripts set.

Run extract_candidates.py first.

Usage: build_curated_input.py <sample> [--tolerance 0.01] [--keep-all-contigs]

Environment: PROJECT_DIR (default: current directory)
             ASMDIR      (default: assembly)
             RESDIR      (default: rescue)
"""
import argparse, collections, os, shutil, sys

BASE   = os.environ.get("PROJECT_DIR", os.getcwd())
ASMDIR = os.environ.get("ASMDIR", "assembly")
RESDIR = os.environ.get("RESDIR", "rescue")

def read_fasta(p):
    name, hdr, buf = None, None, []
    for line in open(p):
        if line.startswith(">"):
            if name: yield name, hdr, "".join(buf)
            hdr = line.rstrip("\n"); name = hdr[1:].split()[0]; buf = []
        else: buf.append(line.strip())
    if name: yield name, hdr, "".join(buf)

ap = argparse.ArgumentParser()
ap.add_argument("sample")
ap.add_argument("--tolerance", type=float, default=0.01,
                help="max fractional length difference from the longest candidate")
ap.add_argument("--keep-all-contigs", action="store_true",
                help="keep every contig from the concordant assemblies, not only "
                     "the chromosome and the previously passing contigs. Needed "
                     "when the genome has further large replicons that never "
                     "reached qc_pass, so they can cluster among the retained set.")
a = ap.parse_args()

d   = f"{BASE}/{ASMDIR}/{a.sample}"
out = f"{BASE}/{RESDIR}/{a.sample}/curated_assemblies"
if os.path.isdir(out): shutil.rmtree(out)
os.makedirs(out)

cand = [l.split("\t") for l in
        open(f"{BASE}/{RESDIR}/{a.sample}/candidates.tsv").read().splitlines()[1:]]
longest = max(int(c[2]) for c in cand)
chrom = {c[0] + ".fasta": c[1] for c in cand
         if abs(int(c[2]) - longest) / longest <= a.tolerance}

passing = collections.defaultdict(set)
for line in open(f"{d}/autocycler_out/clustering/clustering.tsv").read().splitlines()[1:]:
    f = line.split("\t")
    if f[1] != "none": passing[f[4]].add(f[5])

print(f"{a.sample}: {len(chrom)} concordant chromosome assemblies "
      f"(within {a.tolerance:.0%} of {longest} bp)")
if len(chrom) < 2:
    print("  NOTE: fewer than two assemblies agree. Whatever comes out of this is a")
    print("  single-assembler result, not a consensus, and must be reported as such.")
kept = 0
for asm, contig in sorted(chrom.items()):
    recs = list(read_fasta(f"{d}/assemblies/{asm}"))
    if not any(n == contig for n, _, _ in recs):
        print(f"  !! {asm}: chromosome contig {contig} missing"); continue
    if a.keep_all_contigs:
        sel = [(h, s) for _, h, s in recs]
    else:
        keep = {contig} | passing.get(asm, set())
        sel = [(h, s) for n, h, s in recs if n in keep]
    with open(f"{out}/{asm}", "w") as fh:
        for h, s in sel:
            fh.write(h + "\n")
            for i in range(0, len(s), 80): fh.write(s[i:i+80] + "\n")
    kept += len(sel)
    print(f"  {asm:<24} chromosome + {len(sel)-1} other contig(s)")
print(f"curated input: {len(os.listdir(out))} assemblies, {kept} contigs -> {out}")

# distinguish several assemblies from several assemblers
algos = {a_.split("_")[0] for a_ in chrom}
print(f"distinct assembler algorithms represented: {len(algos)} ({', '.join(sorted(algos))})")
