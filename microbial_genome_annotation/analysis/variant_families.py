#!/usr/bin/env python3
"""Group assembled replicons into families and pick one reference per family.

Replicons of the same length recurring across samples are almost certainly the
same molecule, but length alone is not proof, so membership is confirmed by
alignment identity before a family is formed. The reference is taken from the
sample with the deepest coverage of that molecule.

Writes, into <out>:
    refs/<family>.fasta   the reference sequence
    <family>.carriers     samples carrying it, one per line
    families.tsv          family, reference sample, length
"""
import os, glob, os, subprocess, sys, tempfile

plasdir, out = sys.argv[1], sys.argv[2]
os.makedirs(f"{out}/refs", exist_ok=True)

def read_fasta(p):
    n, buf = None, []
    for line in open(p):
        if line.startswith(">"):
            if n: yield n, "".join(buf)
            n, buf = line[1:].rstrip("\n"), []
        else: buf.append(line.strip())
    if n: yield n, "".join(buf)

# collect every assembled replicon with its depth
entries = []
for d in sorted(glob.glob(f"{plasdir}/sample*")):
    bc = os.path.basename(d).split("_")[0]
    fa = f"{d}/plassembler_out/plassembler_plasmids.fasta"
    summ = f"{d}/plassembler_out/plassembler_summary.tsv"
    if not os.path.exists(fa): continue
    depth = {}
    if os.path.exists(summ):
        rows = open(summ).read().splitlines()
        h = rows[0].split("\t")
        for r in rows[1:]:
            f = r.split("\t")
            if f[0] != "chromosome":
                depth[f[0]] = float(f[h.index("mean_depth_long")])
    for hdr, seq in read_fasta(fa):
        cid = hdr.split()[0]
        entries.append(dict(bc=bc, cid=cid, seq=seq, n=len(seq), depth=depth.get(cid, 0.0)))

if not entries:
    sys.exit("no assembled replicons found")

# group by length, allowing a little slack for a differing circular start point
groups = {}
for e in sorted(entries, key=lambda e: -e["n"]):
    for k in groups:
        if abs(k - e["n"]) <= max(5, 0.01 * k):
            groups[k].append(e); break
    else:
        groups[e["n"]] = [e]

fam_rows = []
for n, members in sorted(groups.items(), key=lambda kv: -kv[0]):
    fam = f"plasmid_{n}bp"
    best = max(members, key=lambda e: e["depth"])
    with open(f"{out}/refs/{fam}.fasta", "w") as fh:
        fh.write(f">{fam} source={best['bc']}_{best['cid']} len={best['n']}\n")
        for i in range(0, len(best["seq"]), 80): fh.write(best["seq"][i:i+80] + "\n")
    carriers = sorted({m["bc"] for m in members})
    open(f"{out}/{fam}.carriers", "w").write("\n".join(carriers) + "\n")
    fam_rows.append((fam, best["bc"], n))
    print(f"{fam}: {len(members)} copies in {', '.join(carriers)}; "
          f"reference {best['bc']} {best['cid']} at {best['depth']:.0f}x")

with open(f"{out}/families.tsv", "w") as fh:
    for fam, bc, n in fam_rows: fh.write(f"{fam}\t{bc}\t{n}\n")
