#!/usr/bin/env python3
"""Audit source floor records against exported faces; not a traversal test."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def has_area(points):
    if len(points) < 3 or not all(math.isfinite(v) for p in points for v in p):
        return False
    origin = points[0]
    for i in range(1, len(points) - 1):
        a = [points[i][j] - origin[j] for j in range(3)]
        b = [points[i + 1][j] - origin[j] for j in range(3)]
        cross = [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
        if sum(x*x for x in cross) > 1e-12:
            return True
    return False


def audit(area_dir):
    gp, rp = area_dir/'geometry/geometry.json', area_dir/'review.json'
    geometry, review = json.loads(gp.read_text()), json.loads(rp.read_text())
    faces = defaultdict(list)
    for face in review['faces']:
        if face['kind'] == 'floor':
            faces[face['region']].append(face)
    counts, missing, degenerate, unbound = Counter(), [], [], []
    regions = {r['id']: r for r in geometry['regions']}
    missing_children = []
    for region in geometry['regions']:
        rid = region['id']
        raw = bytes.fromhex(region['raw_hex'])
        role = region.get('record_role')
        if region.get('floor_subdivisions'):
            counts['owners_replaced_by_subdivisions'] += 1
            for child in region['floor_subdivisions']:
                counts['subdivision_references'] += 1
                record = regions.get(child)
                if record is None:
                    missing_children.append({'owner': rid, 'child': child, 'reason': 'missing record'})
                elif child in faces:
                    counts['subdivision_floors_present'] += 1
                elif bytes.fromhex(record['raw_hex'])[32] == 255:
                    counts['explicit_floorless_subdivisions'] += 1
                else:
                    missing_children.append({'owner': rid, 'child': child, 'reason': 'missing floor'})
            continue
        if role != 'primary_region':
            counts['helper_records'] += 1
            continue
        floor, ceiling = region.get('floor_corners'), region.get('ceiling_corners')
        if raw[32] == 255:
            counts['explicit_floorless_primary'] += 1
            continue
        if not floor or not ceiling:
            counts['missing_height_data'] += 1
            missing.append(rid)
            continue
        if max(c-f for f, c in zip(floor, ceiling)) <= 0:
            counts['nonpositive_primary'] += 1
            continue
        counts['eligible_primary'] += 1
        if not faces[rid]:
            missing.append(rid)
    # Inspect exported helper floors too, without assuming every helper is a floor.
    for rid, rows in faces.items():
        if not any(has_area(f['points']) for f in rows):
            degenerate.append(rid)
        if any(str(f.get('material')) not in review['materials'] for f in rows):
            unbound.append(rid)
    return {'area': area_dir.name, 'geometry_sha256': digest(gp),
            'review_sha256': digest(rp), 'counts': dict(counts),
            'exported_floor_regions': len(faces), 'missing_primary_floors': missing,
            'missing_subdivision_floors': missing_children,
            'degenerate_floor_regions': degenerate, 'unbound_floor_regions': unbound}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--map-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    index = args.map_root/'index.json'
    rows = [audit(args.map_root/a['id']) for a in json.loads(index.read_text())['areas']]
    report = {'scope': 'Primary floor presence and exported polygon/material checks. '
              'Subdivision references checked for face presence; geometric tiling, winding, '
              'collision, traversal and original fidelity are not established.',
              'index_sha256': digest(index), 'areas': rows,
              'totals': {key: sum(len(r[key]) for r in rows) for key in
                         ('missing_primary_floors', 'missing_subdivision_floors',
                          'degenerate_floor_regions', 'unbound_floor_regions')}}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report['totals']))
    return int(any(report['totals'].values()))


if __name__ == '__main__':
    raise SystemExit(main())
