#!/usr/bin/env python3
"""Prepare the eight existing Hive curse-region bindings from original records."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from build_game_atlas import parse_mix, section, u32
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from lol2_geometry_format import slope_corners, s16

ARCHIVE = 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
GEOMETRY = '69a9c0dd739ad36691c6513d53cf007204aa3bd35d5762e8f8f4e8c6dbcb9e85'
# Existing runtime admission regions, in their established output order.
BINDINGS = [(389,722,None),(391,736,None),(392,756,None),(393,784,None),
            (812,6316,73),(818,6344,73),(1259,6846,None),(1260,6852,None)]


def require(value, message):
    if not value:
        raise ValueError(message)


def prepare(game, output):
    require(not output.exists(), 'Output must be a fresh directory')
    require(output != game and output not in game.parents and game not in output.parents, 'Output overlaps original game')
    archive = (game / 'DAT/L5_HC.MIX').read_bytes()
    require(hashlib.sha256(archive).hexdigest() == ARCHIVE, 'Unsupported Hive archive')
    entries = [e for e in parse_mix(archive) if e['key'] == 3776990464]
    require(len(entries) == 1, 'Expected one Hive geometry entry')
    entry = entries[0]
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    require(hashlib.sha256(raw).hexdigest() == GEOMETRY, 'Unsupported Hive geometry')
    owners, _ = collect_owners(raw, entry['offset'], u32(raw, 0x58))
    _, _, stream = section(raw, 0x3c, 0x84, 1)
    commands = dict(groups(stream))
    _, _, vb = section(raw, 4, 0x50, 8)
    _, _, rb = section(raw, 12, 0x58, 44)
    vertices = list(struct.iter_unpack('<ii', vb))
    records = list(struct.iter_unpack('<22H', rb))
    rows = []
    for region, group, predicate in BINDINGS:
        matches = [o for o in owners if o['owner_kind'] == 'region' and o['owner'] == region]
        require(len(matches) == 1, 'Expected one curse-region owner')
        owner = matches[0]
        require((owner['stream'], owner['event'], owner['group'], owner['predicate']) ==
                (0, 2, group, predicate), 'Curse-region event binding differs')
        record = records[region]
        heights = slope_corners(records, region)
        rows.append(dict(region=region,
                         polygon=[[vertices[v][0] / 65536, -vertices[v][1] / 65536] for v in record[6:10]],
                         floor=s16(record[10]), floor_min=min(heights), floor_max=max(heights),
                         commands=[body.hex() for _, body in commands[group]]))
    target = output / 'assets/lol2/generated/hive_curse/regions.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(dict(archive_sha256=ARCHIVE, regions=rows), indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        prepare(args.game.resolve(), args.output_root.resolve())
    except (ValueError, OSError, KeyError, IndexError, struct.error) as error:
        parser.error(str(error))
    print('PASS eight original Hive curse-region bindings')


if __name__ == '__main__':
    main()
