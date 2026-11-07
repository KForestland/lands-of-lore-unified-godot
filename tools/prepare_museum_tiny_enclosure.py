#!/usr/bin/env python3
"""Pin the Museum (L3_DH) Long arm chute: the regions a human can stand in but never leave.

Regions 957/959-966 (the sludge chute between the Long arm pit tunnel and the duct mouth) have vertical clearance
50-70, so the human body (height 46, player_form_body.HEIGHTS) fits inside. Their only neighbours outside the set are
region 958 (clearance 20, toward the pit tunnel) and region 967 (clearance 30, the duct mouth, itself a human-return
region). Neither admits a human, so a player who becomes human (or beast) inside the chute cannot leave it. The set is
the clearance>=46 neighbour component of region 965 in the published geometry; both exits are static (no owner).
Usage: prepare_museum_tiny_enclosure.py --output scripts/lol2/museum_tiny_enclosure_source.json
"""
import argparse, hashlib, json, sys
from pathlib import Path

GEOMETRY = Path('~/lol2_out/museum_geometry_20260913/geometry.json')
GEOMETRY_SHA256 = 'bae648d2fcc713bcb45eddad351171cfc014bf41c7e98e37176f98e4b44034ff'
HUMAN_HEIGHT = 46  # player_form_body.HEIGHTS[0]
EXPECTED = [957, 959, 960, 961, 962, 963, 964, 965, 966]
EXITS = {958: 20, 967: 30}


def clearance(r):
    return min(c - f for c, f in zip(r['ceiling_corners'], r['floor_corners']))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    data = GEOMETRY.read_bytes()
    if hashlib.sha256(data).hexdigest() != GEOMETRY_SHA256: sys.exit('unexpected geometry ' + str(GEOMETRY))
    g = json.loads(data); R = {r['id']: r for r in g['regions']}; V = g['vertices_fixed']
    fits = lambda i: i in R and R[i].get('ceiling_corners') and clearance(R[i]) >= HUMAN_HEIGHT
    seen, stack = {965}, [965]
    while stack:
        for b in R[stack.pop()]['neighbors']:
            if b not in seen and fits(b): seen.add(b); stack.append(b)
    assert sorted(seen) == EXPECTED, sorted(seen)
    exits = {b for r in seen for b in R[r]['neighbors'] if b is not None and b not in seen}
    assert {b: clearance(R[b]) for b in exits} == EXITS, exits
    assert all(R[b].get('owner') is None for b in exits)
    regions = {}
    for r in EXPECTED:
        corners = R[r]['floor_corners']
        regions[str(r)] = dict(polygon=[[V[v][0] / 65536, -V[v][1] / 65536] for v in R[r]['vertex_indices']],
                               floor=[min(corners), max(corners)], clearance=clearance(R[r]))
    result = dict(version=1, source=dict(area='L3_DH', geometry_sha256=GEOMETRY_SHA256), human_height=HUMAN_HEIGHT,
                  exits={str(k): v for k, v in EXITS.items()}, regions=regions,
                  scope='Static clearance>=46 neighbour component of region 965 whose only exits are lizard-height. '
                        'Runtime use (keep tiny form inside, restore it for a trapped save) is a modern softlock adapter.')
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS museum tiny enclosure: %d regions, exits %s' % (len(regions), EXITS))


if __name__ == '__main__':
    main()
