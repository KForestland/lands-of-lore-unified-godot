#!/usr/bin/env python3
"""Prepare the five Cave first-contact curse regions from original records."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from build_game_atlas import parse_mix, section, u32
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from lol2_geometry_format import slope_corners

ARCHIVE = '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'
GEOMETRY = 'd681fa1e25d6eec6824d0772b65714fd610deaea6a148c43c538229ac90c7795'


def require(value, message):
    if not value:
        raise ValueError(message)


def prepare(game, output):
    require(not output.exists(), 'Output must be a fresh directory')
    require(output != game and output not in game.parents and game not in output.parents, 'Output overlaps original game')
    archive = (game / 'DAT/L1_DC.MIX').read_bytes()
    require(hashlib.sha256(archive).hexdigest() == ARCHIVE, 'Unsupported Cave archive')
    entries = [e for e in parse_mix(archive) if e['key'] == 2971673856]
    require(len(entries) == 1, 'Expected one Cave geometry entry')
    entry = entries[0]
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    require(hashlib.sha256(raw).hexdigest() == GEOMETRY, 'Unsupported Cave geometry')
    owners, _ = collect_owners(raw, entry['offset'], u32(raw, 0x58))
    _, _, commands = section(raw, 0x3c, 0x84, 1)
    parsed = dict(groups(commands))
    _, _, predicates = section(raw, 0xbc, 0xb8, 5)
    _, _, vertex_bytes = section(raw, 4, 0x50, 8)
    _, _, region_bytes = section(raw, 12, 0x58, 44)
    vertices = list(struct.iter_unpack('<ii', vertex_bytes))
    records = list(struct.iter_unpack('<22H', region_bytes))
    regions = []
    for owner in owners:
        if owner['stream'] != 0 or owner['owner_kind'] != 'region' or owner['event'] != 4:
            continue
        predicate = owner['predicate']
        if predicate is None or predicates[predicate * 5:(predicate + 1) * 5].hex() != '0003010000':
            continue
        rows = parsed[owner['group']]
        if [body.hex() for _, body in rows] != ['020100001324', 'c60000000101']:
            continue
        request = dict(group=owner['group'], command_offset=rows[0][0], command_hex=rows[0][1].hex(),
                       owner=owner, predicate_hex='0003010000', commands=[body.hex() for _, body in rows])
        region = owner['owner']
        heights = slope_corners(records, region)
        polygon = [[vertices[i][0] / 65536, -vertices[i][1] / 65536] for i in records[region][6:10]]
        regions.append(dict(region=region, group=owner['group'], polygon=polygon,
                            floor_min=min(heights), floor_max=max(heights), source=request))
    regions.sort(key=lambda row: row['group'])
    require([(r['region'], r['group']) for r in regions] == [(1357,1720),(1396,1936),(1397,1954),(1405,1972),(1408,1990)], 'Curse region bindings differ')
    result = dict(archive_sha256=ARCHIVE, geometry_sha256=GEOMETRY, regions=regions,
                  scope='Source event4 first contact, predicate local1==0, random form command then local1=1. Region631 group256 excluded because its other encounter effects are not integrated.')
    target = output / 'assets/lol2/generated/cave_curse/regions.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(result, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        prepare(args.game.resolve(), args.output_root.resolve())
    except (ValueError, OSError, KeyError, IndexError, struct.error) as error:
        parser.error(str(error))
    print('PASS five original Cave first-contact curse regions')


if __name__ == '__main__':
    main()
