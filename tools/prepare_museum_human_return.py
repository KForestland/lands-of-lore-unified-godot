#!/usr/bin/env python3
"""Pin every Museum (L3_DH) region whose record runs player op2 sub0x3C (repeatable human request).

Each owner is region kind2 event0 with no predicate and the single command 020100003c00. The Long arm pack hosts the
four duct regions (967/1436/1437/1463); the original also has regions 58, 444 and 1474 in the main rooms. With the
source open-ended Cave form (region631 op2 sub0x13 argument0) those are where a cursed player naturally becomes human
again. Polygons and floor bounds follow prepare_museum_long_arm.region_contract (floor_corners, no overrides apply).
Usage: prepare_museum_human_return.py --output scripts/lol2/museum_human_return_source.json
"""
import argparse, hashlib, json, sys
from pathlib import Path
from verify_actor_item_grants import source_area

GEOMETRY = Path('~/lol2_out/all_maps_20260922/L3_DH').parents[1] / 'museum_geometry_20260913/geometry.json'
EXPECTED = [58, 444, 967, 1436, 1437, 1463, 1474]
LONG_ARM = [967, 1436, 1437, 1463]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    area, arc, entry, raw, owners, streams = source_area('L3_DH')
    found = {}
    for o in owners:
        commands = [c['raw_hex'] for c in streams[o['stream']][o['group']]]
        if '020100003c00' not in commands: continue
        assert o['owner_kind'] == 'region' and o['event'] == 2 and o['value'] == 0 and o['predicate'] is None, o
        assert commands == ['020100003c00'], (o, commands)
        found[o['owner']] = dict(group=o['group'], archive_offset=o['archive_offset'],
                                 raw=arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]].hex(), commands=commands)
    assert sorted(found) == EXPECTED, sorted(found)
    geometry_bytes = GEOMETRY.read_bytes()
    g = json.loads(geometry_bytes); R = {r['id']: r for r in g['regions']}; V = g['vertices_fixed']
    regions = {}
    for r in EXPECTED:
        corners = R[r]['floor_corners']
        regions[str(r)] = dict(polygon=[[V[v][0] / 65536, -V[v][1] / 65536] for v in R[r]['vertex_indices']],
                               floor=[min(corners), max(corners)], **found[r])
    # Duct rows must equal the Long arm pack's published human_return rows exactly.
    published = json.loads((Path(__file__).resolve().parents[1] / 'scripts/lol2/museum_long_arm_source.json').read_text())['regions']['human_return']
    for r in LONG_ARM:
        assert {k: regions[str(r)][k] for k in ('polygon', 'floor')} == published[str(r)], r
    result = dict(version=1, source=dict(area='L3_DH', archive_sha256=hashlib.sha256(arc).hexdigest(),
                                         geometry_sha256=hashlib.sha256(geometry_bytes).hexdigest()),
                  command='020100003c00', regions=regions,
                  scope='Region kind2 event0 (entry), no predicate, repeatable player op2 sub0x3C human request; '
                        'admission bit0x10 and a nonhuman current form are runtime conditions.')
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS museum human return: %d regions (%s)' % (len(regions), ','.join(map(str, EXPECTED))))


if __name__ == '__main__':
    main()
