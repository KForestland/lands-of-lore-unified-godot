#!/usr/bin/env python3
"""Prepare existing Cave start and entrance Roach data without native replay."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from lol2_source_format import parse_mix, u32
from lol2_geometry_format import slope_corners
from lol2_creature_sprite_format import parse_states

ARCHIVE = '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'
EXE = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
SPANS = [(0x14f0ce, 0x14f11a, '589fb44c04de5771465c79805581782346cb7f39ea6aa5c575b487120843df6e'),
         (0x665ec, 0x66620, '496ea4ea9bbd231f5bbb6e4dd59baf37cc84c5d2ed6cd623c0e79953466cda07')]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require(value, message):
    if not value:
        raise ValueError(message)


def prepare(game, output):
    require(not output.exists(), 'Output must be a fresh directory')
    require(output != game and output not in game.parents and game not in output.parents, 'Output overlaps original game')
    arc = (game / 'DAT/L1_DC.MIX').read_bytes()
    exe = (game / 'LOLG.DAT').read_bytes()
    require(sha(arc) == ARCHIVE and sha(exe) == EXE, 'Unsupported original game data')
    entries = parse_mix(arc)
    def entry(key):
        matches = [e for e in entries if e['key'] == key]
        require(len(matches) == 1, 'Expected one archive entry')
        e = matches[0]
        return e, arc[e['offset']:e['offset'] + e['size']]
    ge, geo = entry(2971673856)
    _, meta = entry(2971019266)
    code = []
    for start, end, wanted in SPANS:
        actual = sha(exe[start + 0x37000:end + 0x37000])
        require(actual == wanted, 'Recorded startup code span differs')
        code.append(dict(start=hex(start), end=hex(end), sha256=actual))
    offset, count = u32(geo, 0x48), u32(geo, 0x90)
    arrivals = [(i, geo[offset + i * 12:offset + (i + 1) * 12]) for i in range(count)]
    matches = [(i, raw) for i, raw in arrivals if raw[8] == 1]
    require(len(matches) == 1, 'Expected one Cave arrival selector1')
    index, raw = matches[0]
    x, y, heading, region, selector, flags, tail = struct.unpack('<hhHHBBH', raw)
    require((x, y, heading, region, selector) == (-953, 4302, 58618, 1231, 1), 'Cave arrival differs')
    records = [struct.unpack_from('<22H', geo, u32(geo, 12) + i * 44) for i in range(u32(geo, 0x58))]
    heights = slope_corners(records, region)
    require(heights == [30] * 4, 'Cave arrival floor differs')
    # startup_cases/level/entry/scope retain the historical native-verifier contract;
    # this command checks its code identity and extracts data, not replaying those cases.
    start = dict(executable_sha256=EXE, archive_sha256=ARCHIVE, startup_cases=2, level=1, entry=1,
                 region=region, position=[x, heights[0], -y], heading=heading, arrival_hex=raw.hex(),
                 archive_offset=ge['offset'] + offset + index * 12, code=code,
                 scope='Both startup-default branches yield area context level1/entry1; actual665EC selects source record. Menu/intro execution is not replayed. Godot adds the fixed body-foot offset and settling clearance.')
    row = geo[u32(geo, 0x1c) + 23 * 56:][:56]
    require(row[32] == 5, 'Roach placement definition differs')
    entity = parse_states(meta)['entities'][5]
    resources = {v['resource_reference'] for state in entity['states'] for v in state['views']}
    require(entity['name'] == 'ROACH' and {733, 769, 794, 810} <= resources, 'Roach view family differs')
    x, y, heading, z = struct.unpack_from('<4h', row)
    roach = dict(actor=23, definition=5, name='ROACH', position=[x, z, -y], heading_units=heading & 65535,
                 placement_hex=row.hex(), source_flags=struct.unpack_from('<H', row, 8)[0],
                 archive_sha256=ARCHIVE, geometry_sha256=sha(geo), metadata_sha256=sha(meta),
                 scope='Original actor23 position/definition/view family. Modern local pursuit/combat tuning; source event scheduling, loot and complete native AI not implemented.')
    for name, data in [('cave_start/start.json', start), ('cave_roach/actor.json', roach)]:
        target = output / 'assets/lol2/generated' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(data, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        prepare(args.game.resolve(), args.output_root.resolve())
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print('PASS Cave arrival and entrance Roach source data')


if __name__ == '__main__':
    main()
