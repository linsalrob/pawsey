#!/usr/bin/env python3
"""Did the input assemblers recover the genome, or is it genuinely absent?

For each sample this compares what the individual input assemblies produced
against what survived to the consensus, and reports the largest cluster that
was rejected. A consensus assembler discards material its inputs disagree on,
so a failed assembly usually means "not agreed" rather than "not present" --
and the way to tell is whether the inputs independently reached a total close
to the genome-size estimate. Compare against samples that succeeded in the same
run: that is the only calibration available.

Plasmid-only assemblers among the inputs are excluded from the chromosome
statistics, since they are not attempting the chromosome.

Usage: diagnose_failures.py [sample ...]

Environment: PROJECT_DIR (default: current directory)
             ASMDIR      (default: assembly)
             LOGDIR      (default: logs)
             PLASMID_ASSEMBLERS  comma separated name prefixes to exclude
                                 (default: plassembler)
"""
import collections, glob, os, re, statistics, sys, yaml

BASE   = os.environ.get("PROJECT_DIR", os.getcwd())
ASMDIR = os.environ.get("ASMDIR", "assembly")
LOGDIR = os.environ.get("LOGDIR", "logs")
SKIP   = tuple(filter(None, os.environ.get("PLASMID_ASSEMBLERS", "plassembler").split(",")))

def genome_size(sample):
    for p in glob.glob(f"{BASE}/{LOGDIR}/*{sample}*.err") + glob.glob(f"{BASE}/{LOGDIR}/*{sample}*.out"):
        for line in open(p, errors="ignore"):
            m = re.search(r"--genome_size\s+(\d+)", line)
            if m: return int(m.group(1))
    return None

samples = sys.argv[1:] or [os.path.basename(d) for d in sorted(glob.glob(f"{BASE}/{ASMDIR}/*"))
                           if os.path.isdir(d)]
cols = ["sample","estimate","consensus","recovered","n_assemblies","median_asm_len",
        "asm_vs_estimate","median_contigs","min_contigs","max_contigs","largest_rejected"]
print("\t".join(cols))
for s in samples:
    d  = f"{BASE}/{ASMDIR}/{s}"
    ct = f"{d}/autocycler_out/clustering/clustering.tsv"
    cy = f"{d}/autocycler_out/consensus_assembly.yaml"
    if not (os.path.exists(ct) and os.path.exists(cy)): continue

    per = collections.defaultdict(lambda: [0, 0])
    with open(ct) as fh:
        next(fh)
        for line in fh:
            f = line.rstrip("\n").split("\t")
            per[f[4]][0] += 1
            per[f[4]][1] += int(f[6])
    chrom = {k: v for k, v in per.items() if not k.startswith(SKIP)}
    if not chrom: continue
    counts = sorted(v[0] for v in chrom.values())
    lens   = sorted(v[1] for v in chrom.values())

    biggest_fail = 0
    for g in glob.glob(f"{d}/autocycler_out/clustering/qc_fail/cluster_*/1_untrimmed.gfa"):
        t = sum(len(line.split("\t")[2]) for line in open(g) if line.startswith("S\t"))
        biggest_fail = max(biggest_fail, t)

    cons = yaml.safe_load(open(cy))["consensus_assembly_bases"]
    gs = genome_size(s)
    med = int(statistics.median(lens))
    print("\t".join(map(str, [
        s, gs if gs else "?", cons,
        f"{cons/gs:.4f}" if gs else "?", len(chrom), med,
        f"{med/gs:.4f}" if gs else "?",
        statistics.median(counts), counts[0], counts[-1], biggest_fail])))
