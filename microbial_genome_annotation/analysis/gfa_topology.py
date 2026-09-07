#!/usr/bin/env python3
"""Report the end-to-end topology of an Autocycler GFA.

GFA link semantics: `L a oa b ob` joins the END of a (in orientation oa) to the
BEGINNING of b (in orientation ob). So for the from-segment '+' means its right
end and '-' its left end, but for the to-segment '+' means its LEFT end and '-'
its right end. Getting the to-segment backwards turns dead-end tips into
bridges and invents circular paths that are not there.
"""
import os, sys
gfa = sys.argv[1]
seg, links = {}, []
for l in open(gfa):
    f = l.rstrip("\n").split("\t")
    if f[0] == "S": seg[f[1]] = f[2]
    elif f[0] == "L": links.append((f[1], f[2], f[3], f[4]))

def frm(s, o): return f"{s}.{'right' if o == '+' else 'left'}"
def to (s, o): return f"{s}.{'left'  if o == '+' else 'right'}"

E = {frozenset((frm(a, ao), to(b, bo))) for a, ao, b, bo in links}
adj = {}
for e in E:
    x, y = sorted(e); adj.setdefault(x, set()).add(y); adj.setdefault(y, set()).add(x)

print(f"{len(seg)} segments, {len(E)} distinct edges")
for s in sorted(seg, key=int):
    for side in ("left", "right"):
        k = f"{s}.{side}"
        n = sorted(adj.get(k, []))
        print(f"  tig{s:<3} {len(seg[s]):>9} bp  {side:<5} -> {n if n else 'DEAD END (tip)'}")

def rc(s): return s.translate(str.maketrans("ACGTacgt", "TGCAtgca"))[::-1]

# walk from the right end of the largest segment back to its left end
big = max(seg, key=lambda s: len(seg[s]))
print(f"\npaths from tig{big}.right back to tig{big}.left:")
def walk(end, seen, ins):
    for nxt in sorted(adj.get(end, [])):
        s, side = nxt.split(".")
        if nxt == f"{big}.left":
            print(f"  CIRCULAR via {'+'.join(x[0] for x in seen) or 'direct join'}  "
                  f"insert={ins or '(none)'} ({len(ins)} bp)")
            continue
        if s == big or s in [x[0] for x in seen]: continue
        piece = seg[s] if side == "left" else rc(seg[s])
        other = f"{s}.{'right' if side == 'left' else 'left'}"
        walk(other, seen + [(s, side)], ins + piece)
walk(f"{big}.right", [], "")
