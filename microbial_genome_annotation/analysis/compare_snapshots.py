#!/usr/bin/env python3
"""Compare two read snapshots and report what changed per sample.

Usage: compare_snapshots.py <old stamp> <new stamp>

Reports the deltas in reads and bases, and names the chunk files added or
removed, so newly arrived data is identifiable rather than merely appearing as
a larger total. That matters because a directory of "new" reads is frequently a
re-export containing the old data as well; see ../AGENTS.md.

Environment: PROJECT_DIR (default: current directory)
"""
import os, sys

BASE = os.path.join(os.environ.get("PROJECT_DIR", os.getcwd()), "snapshots")

def load(stamp):
    rows = open(f"{BASE}/{stamp}/snapshot.tsv").read().splitlines()
    hdr = rows[0].split("\t")
    return {r.split("\t")[0]: dict(zip(hdr, r.split("\t"))) for r in rows[1:]}

def files(stamp):
    p = f"{BASE}/{stamp}/file_manifest.tsv"
    out = {}
    if os.path.exists(p):
        for line in open(p):
            f = line.rstrip("\n").split("\t")
            if len(f) >= 2: out.setdefault(f[0], set()).add(os.path.basename(f[1]))
    return out

if len(sys.argv) < 3:
    sys.exit(__doc__)
old_s, new_s = sys.argv[1], sys.argv[2]
old, new = load(old_s), load(new_s)
fo, fn = files(old_s), files(new_s)

print(f"comparing {old_s} -> {new_s}\n")
print(f"{'sample':<16} {'reads_before':>13} {'reads_after':>13} {'d_reads':>12} "
      f"{'bases_before':>15} {'bases_after':>15} {'d_bases':>15} {'new':>5}")
tr = tb = 0
for s in sorted(set(old) | set(new)):
    o, n = old.get(s), new.get(s)
    ro = int(o["reads"]) if o else 0; rn = int(n["reads"]) if n else 0
    bo = int(o["bases"]) if o else 0; bn = int(n["bases"]) if n else 0
    added   = sorted(fn.get(s, set()) - fo.get(s, set()))
    removed = sorted(fo.get(s, set()) - fn.get(s, set()))
    tr += rn - ro; tb += bn - bo
    flag = "" if rn == ro else "  <-- CHANGED"
    print(f"{s:<16} {ro:>13,} {rn:>13,} {rn-ro:>+12,} {bo:>15,} {bn:>15,} "
          f"{bn-bo:>+15,} {len(added):>5}{flag}")
    for a in added:   print(f"                 + {a}")
    for r in removed: print(f"                 - {r}   REMOVED")
print(f"\ntotal change: {tr:+,} reads, {tb:+,} bases ({tb/1e9:+.2f} Gbp)")

# The overlap check that matters: are the old files still present unchanged?
shared = {s: fo.get(s, set()) & fn.get(s, set()) for s in fo}
n_shared = sum(len(v) for v in shared.values())
n_old = sum(len(v) for v in fo.values())
if n_old and n_shared == n_old:
    print(f"\nNOTE: all {n_old} files from {old_s} are also present in {new_s}.")
    print("If these are two directories rather than two states of one directory,")
    print("the newer is a SUPERSET and must not be concatenated with the older.")
