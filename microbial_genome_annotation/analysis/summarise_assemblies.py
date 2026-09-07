#!/usr/bin/env python3
"""Summarise Autocycler consensus assemblies across a project.

Autocycler groups contigs into clusters, one per replicon. A cluster reduced to
a single circular unitig is resolved; a cluster left as many unitigs means that
replicon did not resolve. Counting FASTA records alone conflates the two, so
clusters and unitigs are reported separately.

The completeness judgement is the recovered fraction, not the sequence count:
see ../AGENTS.md for why a low contig count is not evidence of a good assembly.

Usage: summarise_assemblies.py [sample ...]        (default: every sample found)

Environment: PROJECT_DIR (default: current directory)
             ASMDIR      (default: assembly)
             LOGDIR      (default: logs)  -- searched for the genome-size estimate
"""
import glob, os, re, sys, yaml

BASE   = os.environ.get("PROJECT_DIR", os.getcwd())
ASMDIR = os.environ.get("ASMDIR", "assembly")
LOGDIR = os.environ.get("LOGDIR", "logs")

def genome_size(sample):
    """Autocycler prints the estimate it used at the subsample step."""
    for p in glob.glob(f"{BASE}/{LOGDIR}/*{sample}*.err") + glob.glob(f"{BASE}/{LOGDIR}/*{sample}*.out"):
        for line in open(p, errors="ignore"):
            m = re.search(r"--genome_size\s+(\d+)", line)
            if m: return int(m.group(1))
    return None

samples = sys.argv[1:] or [os.path.basename(d) for d in sorted(glob.glob(f"{BASE}/{ASMDIR}/*"))
                           if os.path.isdir(d)]

hdr = (f"{'sample':<16} {'clusters':>8} {'unitigs':>8} {'assembled':>12} {'estimate':>12} "
       f"{'recovered':>10} {'resolved':>9}  replicons")
print(hdr); print("-" * len(hdr))
for s in samples:
    y = f"{BASE}/{ASMDIR}/{s}/autocycler_out/consensus_assembly.yaml"
    if not os.path.exists(y):
        print(f"{s:<16} {'-':>8} {'-':>8} {'-':>12} {'-':>12} {'-':>10} {'-':>9}  NO ASSEMBLY")
        continue
    d = yaml.safe_load(open(y))
    cl = d["consensus_assembly_clusters"]
    gs = genome_size(s)
    frac = f"{d['consensus_assembly_bases']/gs:.4f}" if gs else "?"
    desc = ", ".join(
        (f"{c['length']/1e6:.2f}Mb" if c["length"] >= 1e6 else f"{c['length']/1e3:.1f}kb")
        + ("" if c["topology"] == "circular" else f"[{c['topology']}:{c['unitigs']}u]")
        for c in sorted(cl, key=lambda c: -c["length"])[:6])
    if len(cl) > 6: desc += f", +{len(cl)-6} more"
    print(f"{s:<16} {len(cl):>8} {d['consensus_assembly_unitigs']:>8} "
          f"{d['consensus_assembly_bases']:>12} {gs if gs else '?':>12} {frac:>10} "
          f"{str(d['consensus_assembly_fully_resolved']):>9}  {desc}")
