#!/usr/bin/env python3
"""Native region-graph reachability of world-item placements (items step 2026-10-31, "reachability first").

For one area: the map pack's regions (geometry.json: quads in vertices_fixed / 65536, native y; `neighbors` per quad edge,
None = wall; `flags` bit0 = player-impassable, the bit region_blockers.gd walls off) form the walk graph. A breadth-first
search from the region under the player's start point gives every region a player can enter without crossing a bit0
region; opcode-197 (dynamic) regions count as the data's initial bit0 in the STRICT pass and as open in the PERMISSIVE pass
(the scripts open them). Each candidate row is reported with its region, that region's floor/ceiling, both verdicts and
the strict hop count. Heights are ignored (the native walk is region-based); the Godot probe (tools/probe_world_items.gd)
covers floor support and line of sight. Nothing here says the original lets the item be taken: that is the pickup rule.

Usage: world_item_reachability.py --area L8_SJ --geometry MAPS/L8_SJ/geometry/geometry.json --start X Y(native)
       --rows candidates.json [--blockers assets/lol2/generated/region_blockers/L8_SJ.json] [--out report.json]
"""
import argparse
import json
from collections import deque
from pathlib import Path


def quad(g, r):
    v = g['vertices_fixed']
    return [(v[i][0] / 65536.0, v[i][1] / 65536.0) for i in r['vertex_indices']]


def inside(pt, poly):
    x, y = pt
    hit = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            hit = not hit
    return hit


def region_at(g, pt):
    found = [r['id'] for r in g['regions'] if inside(pt, quad(g, r))]
    return found


def bfs(g, start, passable):
    dist = {start: 0}
    queue = deque([start])
    regions = {r['id']: r for r in g['regions']}
    while queue:
        cur = queue.popleft()
        for n in regions[cur]['neighbors']:
            if n is None or n < 0 or n in dist or n not in passable:
                continue
            dist[n] = dist[cur] + 1
            queue.append(n)
    return dist


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--area', required=True)
    p.add_argument('--geometry', type=Path, required=True)
    p.add_argument('--start', type=float, nargs=2, required=True, metavar=('X', 'Y'), help='native x y of the player start')
    p.add_argument('--rows', type=Path, required=True, help='candidate rows JSON [{area,row,name,region,native_position:[x,y,h]}]')
    p.add_argument('--blockers', type=Path, help='region_blockers pack (version 2) for the dynamic op197 regions')
    p.add_argument('--out', type=Path)
    a = p.parse_args()
    g = json.loads(a.geometry.read_text())
    if g['source']['area_id'] != a.area:
        raise SystemExit(f"geometry is {g['source']['area_id']}, not {a.area}")
    dynamic = {}
    if a.blockers and a.blockers.exists():
        dynamic = {int(k): bool(v) for k, v in json.loads(a.blockers.read_text()).get('dynamic_initial', {}).items()}
    regions = {r['id']: r for r in g['regions']}
    strict = {r['id'] for r in g['regions'] if not (r['flags'] & 1)} | {k for k, blocked in dynamic.items() if not blocked}
    strict -= {k for k, blocked in dynamic.items() if blocked}
    permissive = {r['id'] for r in g['regions'] if not (r['flags'] & 1)} | set(dynamic)
    starts = region_at(g, tuple(a.start))
    if not starts:
        raise SystemExit(f'start {a.start} lies in no region of {a.area}')
    start = starts[0]
    d_strict = bfs(g, start, strict | {start})
    d_perm = bfs(g, start, permissive | {start})
    out = {'area': a.area, 'geometry_sha256': g['source']['sha256'], 'start': a.start, 'start_region': start,
           'start_candidates': starts, 'regions': len(g['regions']), 'bit0_regions': sum(1 for r in g['regions'] if r['flags'] & 1),
           'dynamic_regions': sorted(dynamic), 'strict_reachable_regions': len(d_strict), 'permissive_reachable_regions': len(d_perm),
           'rows': []}
    for row in json.loads(a.rows.read_text()):
        if row['area'] != a.area:
            continue
        x, y = row['native_position'][0], row['native_position'][1]
        at = region_at(g, (x, y))
        census_region = int(row['region'])
        r = regions.get(census_region)
        out['rows'].append({
            'row': row['row'], 'name': row['name'], 'flags': row['flags'], 'census_region': census_region,
            'point_regions': at, 'census_region_contains_point': census_region in at,
            'region_bit0': bool(r['flags'] & 1) if r else None,
            'region_floor_ceiling': [r['floor_base'], r['ceiling_base']] if r else None,
            'strict_reachable': census_region in d_strict, 'strict_hops': d_strict.get(census_region),
            'permissive_reachable': census_region in d_perm, 'permissive_hops': d_perm.get(census_region)})
    text = json.dumps(out, indent=1)
    if a.out:
        a.out.write_text(text + '\n')
    for row in out['rows']:
        print(f"{a.area} row {row['row']:>3} {row['name']:<16} region {row['census_region']:>5} contains={row['census_region_contains_point']} "
              f"bit0={row['region_bit0']} floor/ceil={row['region_floor_ceiling']} strict={row['strict_reachable']} ({row['strict_hops']}) "
              f"permissive={row['permissive_reachable']} ({row['permissive_hops']})")
    print(f"{a.area}: start region {start} (candidates {starts}); {len(g['regions'])} regions, {out['bit0_regions']} bit0, "
          f"{len(dynamic)} dynamic; strict reach {len(d_strict)}, permissive {len(d_perm)}")


if __name__ == '__main__':
    main()
