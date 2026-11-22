#!/usr/bin/env python3
"""Thin hanging regions that no body can stand in, made solid to the player (owner F10 2026-11-15 03-27-37, L10 yard).

A region whose ceiling is less than 16 above its floor (the smallest body, the lizard) holds no body. When such a region
hangs over walkable ground with less than a standing body (46) between them, a body walking on that ground can slide
under its floor face and be wedged between the two (the owner's Cemetery yard, region 1029 floor 35 / ceiling 45 over the
yard at 0: feet pushed 7 into the yard floor, every direction blocked). The native walls on such a region's edges cover
only its own 10 units. Output per region: its floor polygons (X/Z), bottom = the highest walkable floor under it, top =
its ceiling. thin_region_blocks.gd builds one convex prism per floor polygon on the region-blocker layer, so rays and
creatures are unaffected, and lifts a body that is already inside one back onto that floor beside it.

Scope (lead 2026-11-15): ceiling - floor > 0 and < 16 (regions with floor == ceiling are left out: closed and door
regions), with walkable floor under it in the gap (0, 46). Pinned to the pack it was read from; on any other pack the
game builds nothing.

  python3 tools/prepare_thin_region_blocks.py --area L10_DC --pack assets/lol2/generated/maps/L10_DC/area_moved.json \\
      --out scripts/lol2/thin_region_blocks/L10_DC.json
"""
import argparse
import hashlib
import json
from collections import defaultdict
from pathlib import Path

SMALLEST_BODY = 16.0
STANDING_BODY = 46.0


def inside(x, z, poly):
    c = False
    for i in range(len(poly)):
        (x1, z1), (x2, z2) = poly[i], poly[i - 1]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


def thin_regions(pack):
    floors, ceilings = defaultdict(list), defaultdict(list)
    for face in pack['faces']:
        points = face.get('points') or []
        if len(points) < 3:
            continue
        if face.get('kind') == 'floor':
            floors[face.get('region')].append(points)
        elif face.get('kind') == 'ceiling':
            ceilings[face.get('region')].append(points)
    rows = []
    for region, polys in floors.items():
        if region not in ceilings:
            continue
        low = min(p[1] for q in polys for p in q)
        top = max(p[1] for q in ceilings[region] for p in q)
        if not 0 < top - low < SMALLEST_BODY:
            continue
        plan = [(p[0], p[2]) for q in polys for p in q]
        cx, cz = sum(p[0] for p in plan) / len(plan), sum(p[1] for p in plan) / len(plan)
        ground = []
        for other, others in floors.items():
            if other == region:
                continue
            for q in others:
                h = max(p[1] for p in q)
                outline = [(p[0], p[2]) for p in q]
                if low - STANDING_BODY < h < low and (inside(cx, cz, outline) or any(inside(x, z, outline) for x, z in plan)):
                    ground.append([other, h])
                    break
        if ground:
            rows.append({'region': region, 'floor': low, 'ceiling': top, 'bottom': max(h for _, h in ground),
                         'ground_regions': sorted(r for r, _ in ground), 'centre': [round(cx), round(cz)],
                         'polygons': [[[p[0], p[2]] for p in q] for q in polys]})
    return sorted(rows, key=lambda r: r['region'])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--area', required=True)
    parser.add_argument('--pack', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    raw = args.pack.read_bytes()
    rows = thin_regions(json.loads(raw))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({'version': 1, 'area': args.area, 'producer': Path(__file__).name,
                                    'pack_sha256': hashlib.sha256(raw).hexdigest(), 'smallest_body': SMALLEST_BODY,
                                    'standing_body': STANDING_BODY, 'regions': rows}, indent=1) + '\n')
    print(f'{args.area}: {len(rows)} thin regions over walkable ground -> {args.out}')


if __name__ == '__main__':
    main()
