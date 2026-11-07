#!/usr/bin/env python3
"""Check the original Hive item rows 5-9 against L5_HC.MIX and GLOBAL.MIX, and their port binding.

Binds identity, definition, native x/y/height, flags, region and the port position (x, height, -y) written in
scripts/lol2/hive_world_items_state.gd. Also confirms rows 4 and 10 carry flags 0x0402 (left unhosted). Height equals
the region floor (AI_COMMS grok_backlog_20261028/G18_hive_placements); this checker does not replay settling.
"""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path
from lol2_source_format import parse_mix, u32

LEVEL_SHA = 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
GEOMETRY_SHA = '69a9c0dd739ad36691c6513d53cf007204aa3bd35d5762e8f8f4e8c6dbcb9e85'
DEFINITIONS_SHA = 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
# row, definition, x, y, height, region
EXPECTED = [(5, 148, -2149, 6758, -1387, 1216), (6, 55, -2636, 8943, -539, 353), (7, 55, -2675, 8947, -539, 353),
            (8, 82, -3713, 6966, -951, 1224), (9, 139, -2772, 7989, -811, 325)]
HELD = [(4, 30), (10, 42)]


def digest(raw): return hashlib.sha256(raw).hexdigest()


def entry(blob, key):
    rows = [r for r in parse_mix(blob) if r['key'] == key]
    if len(rows) != 1: raise ValueError('Expected one archive entry')
    return blob[rows[0]['offset']:rows[0]['offset'] + rows[0]['size']]


def verify(game, source_path):
    archive = (game / 'DAT/L5_HC.MIX').read_bytes()
    if digest(archive) != LEVEL_SHA: raise ValueError('Unsupported original DAT/L5_HC.MIX')
    geometry = entry(archive, 3776990464)
    if digest(geometry) != GEOMETRY_SHA: raise ValueError('Unsupported Hive geometry')
    definitions = entry((game / 'GLOBAL.MIX').read_bytes(), 3984507021)
    if digest(definitions) != DEFINITIONS_SHA: raise ValueError('Unsupported GLOBAL definitions')
    if u32(geometry, 0x6C) != 27: raise ValueError('Expected 27 Hive item rows')
    source = source_path.read_text()
    base = u32(geometry, 0x20)
    rows = []
    for row, definition, x, y, height, region in EXPECTED:
        raw = geometry[base + row * 37:][:37]
        record = definitions[u32(definitions, 4) + definition * 91:][:91]
        if struct.unpack_from('<hh', raw) != (x, y) or struct.unpack_from('<h', raw, 6)[0] != height:
            raise ValueError(f'Row {row} position differs')
        flags, actual_region = struct.unpack_from('<HH', raw, 8)
        if flags != 2 or actual_region != region: raise ValueError(f'Row {row} flags/region differ')
        if u32(raw, 32) != u32(record, 24): raise ValueError(f'Row {row} identity differs from definition {definition}')
        if f'Vector3({x},{height},{-y})' not in source: raise ValueError(f'Row {row} port position missing')
        if str(u32(raw, 32)) not in source: raise ValueError(f'Row {row} identity missing in port source')
        rows.append(dict(row=row, definition=definition, identity=u32(raw, 32), native=[x, y, height], region=region,
                         flags=flags, port_position=[x, height, -y], placement_sha256=digest(raw)))
    held = []
    for row, definition in HELD:
        raw = geometry[base + row * 37:][:37]
        record = definitions[u32(definitions, 4) + definition * 91:][:91]
        flags = struct.unpack_from('<H', raw, 8)[0]
        if flags != 0x0402 or u32(raw, 32) != u32(record, 24): raise ValueError(f'Held row {row} differs')
        held.append(dict(row=row, definition=definition, flags=flags, reason='bit 0x0400 reader untraced (G34/G36)'))
    ids = re.search(r'const ROWS := \[([^\]]*)\]', source)
    if ids is None or [int(v) for v in ids.group(1).split(',')] != [r[0] for r in EXPECTED]:
        raise ValueError('Port ROWS differ')
    return dict(passed=True, rows=rows, held=held, level_sha256=LEVEL_SHA, geometry_sha256=GEOMETRY_SHA,
                definitions_sha256=DEFINITIONS_SHA,
                scope='Original placement bytes and port binding only. Heights are raw region floors (G18), not a settling replay. Pickup admission, reach and item handlers are not replayed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1] / 'scripts/lol2/hive_world_items_state.gd')
    args = parser.parse_args()
    try:
        print(json.dumps(verify(args.game.resolve(), args.source.resolve()), indent=2))
    except (OSError, ValueError, StopIteration) as error:
        parser.error(str(error) or type(error).__name__)
