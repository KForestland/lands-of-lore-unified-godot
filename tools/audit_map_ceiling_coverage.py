#!/usr/bin/env python3
"""Check source ceiling admission, child references, bindings and polygon area."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path

from audit_map_floor_coverage import digest, has_area


def audit(area_dir):
    gp, rp = area_dir/'geometry/geometry.json', area_dir/'review.json'
    geometry, review = json.loads(gp.read_text()), json.loads(rp.read_text())
    faces = defaultdict(list)
    for face in review['faces']:
        if face['kind'] == 'ceiling':
            faces[face['region']].append(face)
    subdivision = geometry['ceiling_subdivisions']
    owners, children = set(subdivision['owners']), set(subdivision['children'])
    regions = {r['id']: r for r in geometry['regions']}
    counts, missing, degenerate, unbound, unexpected = Counter(), [], [], [], []
    for rid in children:
        if rid not in regions:
            missing.append({'region': rid, 'reason': 'missing child record'})
    expected = set()
    for region in geometry['regions']:
        rid = region['id']
        raw = bytes.fromhex(region['raw_hex'])
        if rid in children:
            selector = raw[32]
            counts['subdivision_records'] += 1
        elif rid in owners:
            counts['suppressed_owner_planes'] += 1
            continue
        elif region.get('standalone_ceiling') and region.get('ceiling_corners') is not None:
            selector = raw[34]
            counts['standalone_records'] += 1
        else:
            counts['non_standalone_records'] += 1
            continue
        if selector == 255:
            counts['explicit_no_ceiling_material'] += 1
            continue
        expected.add(rid)
        if rid not in faces:
            missing.append({'region': rid, 'reason': 'expected ceiling face absent'})
    for rid, rows in faces.items():
        if rid not in expected:
            unexpected.append(rid)
        if not any(has_area(f['points']) for f in rows):
            degenerate.append(rid)
        if any(str(f.get('material')) not in review['materials'] for f in rows):
            unbound.append(rid)
    return {'area': area_dir.name, 'geometry_sha256': digest(gp),
            'review_sha256': digest(rp), 'counts': dict(counts),
            'expected_ceiling_regions': len(expected), 'exported_ceiling_regions': len(faces),
            'missing_ceilings': missing, 'unexpected_ceilings': unexpected,
            'degenerate_ceilings': degenerate, 'unbound_ceilings': unbound,
            'unresolved_children': subdivision['unresolved_children']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--map-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    index = args.map_root/'index.json'
    rows = [audit(args.map_root/a['id']) for a in json.loads(index.read_text())['areas']]
    report = {'scope': 'Ceiling admission and face presence, including child records. '
              'Does not establish subdivision tiling, winding, UV parity or traversal.',
              'index_sha256': digest(index), 'areas': rows,
              'totals': {key: sum(len(r[key]) for r in rows) for key in
                         ('missing_ceilings', 'unexpected_ceilings', 'degenerate_ceilings',
                          'unbound_ceilings', 'unresolved_children')}}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report['totals']))
    return int(any(report['totals'].values()))


if __name__ == '__main__':
    raise SystemExit(main())
