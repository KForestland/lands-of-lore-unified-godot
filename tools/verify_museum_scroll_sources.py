#!/usr/bin/env python3
"""Check original Museum scroll placement/definition binding; settling replay is separate evidence."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from lol2_source_format import parse_mix, u32


def entry(blob, key):
    row = next(r for r in parse_mix(blob) if r['key'] == key)
    return blob[row['offset']:row['offset'] + row['size']]


def verify(game):
    archive = (game / 'DAT/L3_DH.MIX').read_bytes()
    assert hashlib.sha256(archive).hexdigest() == 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'
    geometry = entry(archive, 3106551060)
    definitions = entry((game / 'DAT/GLOBAL.MIX').read_bytes(), 3984507021)
    assert hashlib.sha256(definitions).hexdigest() == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    expected = [(12,75,-1937,1168,1465),(13,75,-1915,1168,1466),(14,148,-1870,1168,1468),(15,148,-1892,1169,1467),(16,149,-1937,1163,1465)]
    source = (Path(__file__).resolve().parents[1] / 'scripts/lol2/museum_scroll_state.gd').read_text()
    rows = []
    for row, definition, x, y, region in expected:
        raw = geometry[u32(geometry,0x20)+row*37:][:37]
        record = definitions[u32(definitions,4)+definition*91:][:91]
        assert struct.unpack_from('<hh',raw) == (x,y)
        assert struct.unpack_from('<h',raw,6)[0] == 8070
        assert struct.unpack_from('<HH',raw,8) == (2,region)
        assert u32(raw,32) == u32(record,24)
        assert f'Vector3({x},30,{-y})' in source
        rows.append(dict(row=row,definition=definition,identity=u32(raw,32),region=region,raw_height=8070,port_position=[x,30,-y],record_sha256=hashlib.sha256(raw).hexdigest()))
    return dict(rows=rows,scope='Original placement identity/XY/rawZ/region and port coordinate binding. Z30 is independently established by continuous native constructor/update replay, not inferred from this checker.')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(verify(args.game),indent=2))
