#!/usr/bin/env python3
"""Give bank-less water regions the surface of the water around them (owner F10 2026-11-04 23:05:28: "cant drown" mid-river).

prepare_liquid_regions.py sets SURFACE = highest dry-neighbour floor; a region with no dry neighbour (the middle of a wide
river) kept surface = its own floor (depth 0), so nobody could drown there. This pass floods surfaces through water regions
that share an edge (two polygon vertices): a bank-less region takes the surface of the NEAREST banked water region
(breadth-first waves from every banked region; on a tie the lower surface, so a cliff bank does not flood a river).
Regions with their own banks are unchanged. Adapter (DEVIATIONS); the native liquid level is not decoded.
Usage: propagate_liquid_surface.py assets/lol2/generated/liquid/L4_HJ.json [...]   (rewrites in place, prints counts)
"""
import json, sys
from collections import defaultdict

def key(p): return (round(p[0], 3), round(p[1], 3))

for path in sys.argv[1:]:
    d = json.load(open(path))
    regs = d['regions']
    by_vertex = defaultdict(set)
    for i, r in enumerate(regs):
        for p in r['polygon']: by_vertex[key(p)].add(i)
    shared = defaultdict(lambda: defaultdict(int))
    for ids in by_vertex.values():
        for a in ids:
            for b in ids:
                if a != b: shared[a][b] += 1
    nbrs = {i: [j for j, c in shared[i].items() if c >= 2] for i in range(len(regs))}
    fixed = 0
    # A region whose highest dry neighbour is no higher than its own bed (a flat shore) holds no water level of its own.
    banked = {i for i, r in enumerate(regs) if r['dry_neighbours'] != 0 and r['surface'] > r['floor']}
    # Connected beds: water regions sharing an edge whose floors differ by at most 30 (one river bed, not the streams above it).
    comp = {}
    for i in range(len(regs)):
        if i in comp: continue
        stack = [i]; comp[i] = i
        while stack:
            a = stack.pop()
            for b in nbrs[a]:
                if b not in comp and abs(regs[b]['floor'] - regs[a]['floor']) <= 30: comp[b] = i; stack.append(b)
    levels = defaultdict(list)
    for i in banked: levels[comp[i]].append(regs[i]['surface'])
    for i, r in enumerate(regs):
        if i in banked: continue
        values = levels.get(comp[i], [])
        if not values: continue
        counts = defaultdict(int)
        for v in values: counts[v] += 1
        level = max(counts, key=lambda v: (counts[v], -v))  # most common bank level of this bed; tie -> lower
        if level > r['surface']:
            r['surface'] = level; r['depth'] = level - r['floor']; r['surface_from'] = 'bed_common_bank'; fixed += 1
    d['scope'] = d['scope'].rstrip() + ' Bank-less regions take the most common bank level of their connected bed (propagate_liquid_surface.py).'
    open(path, 'w').write(json.dumps(d, indent=1) + '\n')
    still = sum(1 for r in regs if r['dry_neighbours'] == 0 and r['depth'] == 0)
    print(f"{path}: {fixed} bank-less regions raised; {still} still depth 0")
