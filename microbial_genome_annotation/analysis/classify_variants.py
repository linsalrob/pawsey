#!/usr/bin/env python3
"""Classify variant sites as real or as ONT basecalling artefacts.

Every sample carrying a replicon family is mapped to one common reference,
including the sample the reference came from. That self-mapping is the
control: at a genuinely variable site the reference sample's own reads agree
with its own assembly, whereas at an error-prone site they do not.

Two things this deliberately gets right, having got them wrong first time:

  * Strand bias is taken from the sample that actually drives the call, i.e.
    the one with the highest alt fraction. Taking the maximum across all
    carriers instead lets a sample with one or two stray alt reads, where
    strand balance is extreme by chance, veto a site that is cleanly supported
    elsewhere.

  * "Carrying the alt" uses a higher threshold than "detectable at all". A
    sample sitting at 0.5% alt is background, not a carrier, and counting it
    as one makes a real difference look like an error shared by everybody.
"""
import os, glob, os, sys, collections

OUT = sys.argv[1]
MIN_DP        = 100
BACKGROUND    = 0.05    # at or below this a sample does not carry the allele
CARRYING      = 0.25    # at or above this it does
HOMOPOLYMER   = 5       # ONT error concentrates in runs this long
STRAND_MAX    = 0.25    # |alt reads on + strand / all alt reads - 0.5|

def read_fasta(p):
    return "".join(l.strip() for l in open(p) if not l.startswith(">"))

def homopolymer_len(seq, pos):
    i = pos - 1
    if not (0 <= i < len(seq)): return 0
    best = 0
    for start in (i - 1, i):
        if not (0 <= start < len(seq)): continue
        b = seq[start]; n = 1
        j = start - 1
        while j >= 0 and seq[j] == b: n += 1; j -= 1
        j = start + 1
        while j < len(seq) and seq[j] == b: n += 1; j += 1
        best = max(best, n)
    return best

def parse_vcf(p):
    sites = {}
    for line in open(p):
        if line.startswith("#"): continue
        f = line.rstrip("\n").split("\t")
        alt = f[4].split(",")[0]
        if alt in (".", "<*>", ""): continue
        d = dict(zip(f[8].split(":"), f[9].split(":")))
        if "AD" not in d: continue
        ad = [int(x) for x in d["AD"].split(",") if x != "."]
        if len(ad) < 2: continue
        dp = sum(ad)
        if dp < MIN_DP: continue
        adf = [int(x) for x in d.get("ADF", "0,0").split(",")]
        adr = [int(x) for x in d.get("ADR", "0,0").split(",")]
        plus  = adf[1] if len(adf) > 1 else 0
        minus = adr[1] if len(adr) > 1 else 0
        sites[int(f[1])] = dict(ref=f[3], alt=alt, dp=dp, vaf=ad[1]/dp,
                                plus=plus, minus=minus,
                                sb=abs(plus/(plus+minus)-0.5) if plus+minus else 0.5,
                                indel=len(f[3]) != len(alt))
    return sites

rows = []
for fam_line in open(f"{OUT}/families.tsv"):
    fam, ref_bc, length = fam_line.rstrip("\n").split("\t")
    seq = read_fasta(f"{OUT}/refs/{fam}.fasta")
    carriers = open(f"{OUT}/{fam}.carriers").read().split()
    per = {bc: parse_vcf(f"{OUT}/vcf/{fam}_{bc}.vcf")
           for bc in carriers if os.path.exists(f"{OUT}/vcf/{fam}_{bc}.vcf")}
    if ref_bc not in per: continue

    for pos in sorted({p for s in per.values() for p in s}):
        vafs = {bc: per[bc].get(pos, {}).get("vaf", 0.0) for bc in per}
        driver = max(vafs, key=vafs.get)
        if vafs[driver] < CARRYING: continue
        d = per[driver][pos]
        hp = homopolymer_len(seq, pos)
        self_vaf = vafs[ref_bc]
        n_carry = sum(1 for v in vafs.values() if v >= CARRYING)
        n_bg    = sum(1 for v in vafs.values() if v <= BACKGROUND)

        if d["indel"] or hp >= HOMOPOLYMER:
            verdict = "LIKELY_ARTEFACT"
        elif d["sb"] > STRAND_MAX:
            verdict = "STRAND_BIASED"
        elif n_carry == len(vafs):
            verdict = "SHARED_ERROR"          # everyone including the reference
        elif n_bg > 0 and vafs[driver] >= 0.90:
            verdict = "FIXED_DIFFERENCE"      # near-fixed in some, absent in others
        elif n_bg > 0:
            verdict = "SUBPOPULATION"         # real, but a minority of molecules
        else:
            verdict = "UNCERTAIN"

        rows.append(dict(family=fam, pos=pos, ref=d["ref"], alt=d["alt"],
                         driver=driver, driver_vaf=round(vafs[driver], 4),
                         driver_dp=d["dp"], strand=f"+{d['plus']}/-{d['minus']}",
                         strand_bias=round(d["sb"], 3), homopolymer=hp,
                         indel=d["indel"], ref_bc=ref_bc, ref_bc_vaf=round(self_vaf, 4),
                         n_carrying=n_carry, n_background=n_bg, n_samples=len(vafs),
                         verdict=verdict,
                         per_sample=";".join(f"{b}:{v:.3f}" for b, v in sorted(vafs.items()))))

cols = ["family","pos","ref","alt","driver","driver_vaf","driver_dp","strand","strand_bias",
        "homopolymer","indel","ref_bc","ref_bc_vaf","n_carrying","n_background","n_samples",
        "verdict","per_sample"]
with open(f"{OUT}/plasmid_variants.tsv", "w") as fh:
    fh.write("\t".join(cols) + "\n")
    for r in sorted(rows, key=lambda r: (r["family"], r["pos"])):
        fh.write("\t".join(str(r[c]) for c in cols) + "\n")

tally = collections.Counter(r["verdict"] for r in rows)
print(f"{len(rows)} sites with an alt allele at >= {CARRYING:.0%} in at least one sample\n")
for k, v in tally.most_common(): print(f"  {k:<18} {v}")
real = [r for r in rows if r["verdict"] in ("FIXED_DIFFERENCE", "SUBPOPULATION")]
print(f"\n{len(real)} sites classified as real")
byfam = collections.Counter((r["family"], r["verdict"]) for r in real)
for (f, v), n in sorted(byfam.items()): print(f"  {f:<18} {v:<18} {n}")
print(f"\nwritten {OUT}/plasmid_variants.tsv")
