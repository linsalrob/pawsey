#!/usr/bin/env python3
"""Pull the contigs of the largest rejected cluster out of the input assemblies.

When a consensus assembly fails, the chromosome is usually sitting in a cluster
that did not reach the support threshold. This writes each candidate to its own
FASTA so they can be compared before any of them is trusted.

Agreement in length is not agreement in sequence. Follow this with
rescue_checks.slurm, and note that the longest candidate may be a chimera that
has concatenated a second replicon onto the chromosome -- use EXCLUDE to drop
one once identified. See ../AGENTS.md.

Usage: extract_candidates.py <sample> [sample ...]

Environment: PROJECT_DIR (default: current directory)
             ASMDIR      (default: assembly)
             RESDIR      (default: rescue)
             EXCLUDE     comma separated assembly names to ignore when choosing
                         the reference, e.g. EXCLUDE=canu_01
"""
import collections, os, sys

BASE   = os.environ.get("PROJECT_DIR", os.getcwd())
ASMDIR = os.environ.get("ASMDIR", "assembly")
RESDIR = os.environ.get("RESDIR", "rescue")
EXCL   = set(filter(None, os.environ.get("EXCLUDE", "").split(",")))

def read_fasta(p):
    name, buf = None, []
    for line in open(p):
        if line.startswith(">"):
            if name: yield name, "".join(buf)
            name, buf = line[1:].split()[0], []
        else: buf.append(line.strip())
    if name: yield name, "".join(buf)

if len(sys.argv) < 2: sys.exit(__doc__)
for sample in sys.argv[1:]:
    d   = f"{BASE}/{ASMDIR}/{sample}"
    out = f"{BASE}/{RESDIR}/{sample}"
    ct  = f"{d}/autocycler_out/clustering/clustering.tsv"
    if not os.path.exists(ct):
        print(f"{sample}: no clustering.tsv"); continue
    os.makedirs(out, exist_ok=True)

    cl = collections.defaultdict(list)
    for line in open(ct).read().splitlines()[1:]:
        f = line.split("\t")
        if f[1] == "none":                       # rejected clusters only
            cl[f[2]].append((f[4], f[5], int(f[6])))
    if EXCL:
        cl = {k: [m for m in v if m[0].replace(".fasta", "") not in EXCL] for k, v in cl.items()}
        cl = {k: v for k, v in cl.items() if v}
    if not cl:
        print(f"{sample}: no rejected clusters"); continue

    key, members = max(cl.items(), key=lambda x: max(m[2] for m in x[1]))
    best = max(m[2] for m in members)
    print(f"{sample}: rejected cluster {key}, {len(members)} members, largest {best}")
    manifest = []
    for asm, contig, length in sorted(members, key=lambda m: -m[2]):
        seq = dict(read_fasta(f"{d}/assemblies/{asm}")).get(contig)
        if seq is None:
            print(f"  !! {asm}:{contig} not found"); continue
        tag = asm.replace(".fasta", "")
        with open(f"{out}/{tag}.fasta", "w") as fh:
            fh.write(f">{tag}_{contig} length={len(seq)}\n")
            for i in range(0, len(seq), 80): fh.write(seq[i:i+80] + "\n")
        manifest.append((tag, contig, len(seq), 100*len(seq)/best))
        print(f"  {tag:<22} {contig:<18} {len(seq):>10} bp  {100*len(seq)/best:5.1f}% of largest")
    with open(f"{out}/candidates.tsv", "w") as fh:
        fh.write("assembly\tcontig\tlength\tpct_of_largest\n")
        for m in manifest: fh.write("%s\t%s\t%d\t%.1f\n" % m)
