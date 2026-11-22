#!/usr/bin/env python3
"""Narrow the Darker Jungle (L8_SJ) boundary-edge list to the hedges that really close the map.

Grok BG26 (owner r17 17-59-34, hedge at (1842, 2499)) made every source wall on a neighbour-less region edge solid:
2906 of the pack's 5101 wall records, which also closed the pit mouth, the tree-room steps and the temple path (the
region neighbour words are not fully decoded, so many linked edges look neighbour-less). This tool keeps only the
walls of one material (the hedge, 276) whose edge is neighbour-less AND has no floor polygon of another region, at
any height up to 60 units above the wall foot, within 60 units beyond it. A hole (the pit) counts as floor beyond.

Inputs: the pack's area.json (faces with kind/material/region/edge/points) and the neighbour-less edge list
({"area": "L8_SJ", "edges": [region*4+edge, ...]}). Output: {"area", "material", "rule", "source", "edges": [...]}
with the edge keys of the kept hedges, for jungle_review.gd boundary_edges_file. Exit 2 on mismatched inputs.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

REACH = (20.0, 40.0, 60.0)
ALONG = (0.25, 0.5, 0.75)
HEIGHT_WINDOW = 60.0
CELL = 256


def point_in_polygon(pt, poly):
    x, z = pt
    inside = False
    n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x1 + (z - z1) * (x2 - x1) / (z2 - z1) > x:
            inside = not inside
    return inside


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--area-json', required=True, type=Path)
    parser.add_argument('--boundary-edges', required=True, type=Path)
    parser.add_argument('--area', default='L8_SJ')
    parser.add_argument('--material', default='276')
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    area = json.loads(args.area_json.read_text())
    edges_doc = json.loads(args.boundary_edges.read_text())
    if str(edges_doc.get('area')) != args.area:
        print(f'boundary edges are for {edges_doc.get("area")}, not {args.area}', file=sys.stderr)
        return 2
    faces = area.get('faces')
    if not isinstance(faces, list) or not faces:
        print('area.json has no faces', file=sys.stderr)
        return 2
    neighbourless = {int(e) for e in edges_doc.get('edges', [])}
    if not neighbourless:
        print('boundary edge list is empty', file=sys.stderr)
        return 2
    floors = []
    grid = {}
    centres = {}
    for f in faces:
        if f.get('kind') != 'floor':
            continue
        pts = f['points']
        xs = [p[0] for p in pts]
        zs = [p[2] for p in pts]
        floors.append(([(p[0], p[2]) for p in pts], min(xs), max(xs), min(zs), max(zs), f['region'], min(p[1] for p in pts)))
        for gx in range(int(min(xs) // CELL), int(max(xs) // CELL) + 1):
            for gz in range(int(min(zs) // CELL), int(max(zs) // CELL) + 1):
                grid.setdefault((gx, gz), []).append(len(floors) - 1)
        c = centres.setdefault(f['region'], [0.0, 0.0, 0])
        for p in pts:
            c[0] += p[0]
            c[1] += p[2]
            c[2] += 1

    def floor_beyond(pt, own_region, ymax):
        for idx in grid.get((int(pt[0] // CELL), int(pt[1] // CELL)), []):
            poly, x0, x1, z0, z1, region, y = floors[idx]
            if region == own_region or y > ymax:
                continue
            if x0 - 1 <= pt[0] <= x1 + 1 and z0 - 1 <= pt[1] <= z1 + 1 and point_in_polygon(pt, poly):
                return True
        return False

    kept = []
    candidates = 0
    for f in faces:
        if f.get('kind') != 'source_wall' or f.get('region') is None or f.get('edge') is None:
            continue
        key = int(f['region']) * 4 + int(f['edge'])
        if key not in neighbourless or not str(f.get('material', '')).startswith(args.material + '_'):
            continue
        candidates += 1
        xz = []
        for p in f['points']:
            q = (p[0], p[2])
            if all(math.hypot(q[0] - u[0], q[1] - u[1]) > 0.5 for u in xz):
                xz.append(q)
        if len(xz) < 2:
            continue
        a, b = xz[0], xz[1]
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        d = (b[0] - a[0], b[1] - a[1])
        length = math.hypot(*d)
        normal = (-d[1] / length, d[0] / length)
        c = centres.get(f['region'])
        if c and (c[0] / c[2] - mid[0]) * normal[0] + (c[1] / c[2] - mid[1]) * normal[1] > 0:
            normal = (-normal[0], -normal[1])
        foot = min(p[1] for p in f['points'])
        open_beyond = any(
            floor_beyond((a[0] + d[0] * t + normal[0] * reach, a[1] + d[1] * t + normal[1] * reach), f['region'], foot + HEIGHT_WINDOW)
            for reach in REACH for t in ALONG)
        if not open_beyond:
            kept.append(key)
    kept = sorted(set(kept))
    out = {
        'area': args.area,
        'material': args.material,
        'rule': f'source wall of material {args.material} on a neighbour-less region edge with no floor of another region '
                f'(any height up to {HEIGHT_WINDOW:g} above the wall foot) within {REACH[-1]:g} units beyond it',
        'source': {
            'area_json': args.area_json.name, 'area_sha256': hashlib.sha256(args.area_json.read_bytes()).hexdigest(),
            'boundary_edges': args.boundary_edges.name, 'boundary_edges_sha256': hashlib.sha256(args.boundary_edges.read_bytes()).hexdigest(),
            'neighbourless_edges': len(neighbourless), 'material_candidates': candidates,
        },
        'edges': kept,
    }
    args.out.write_text(json.dumps(out, separators=(',', ':')) + '\n')
    print(f'{args.area}: {len(neighbourless)} neighbour-less edges, {candidates} material-{args.material} walls on them, {len(kept)} kept as boundary -> {args.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
