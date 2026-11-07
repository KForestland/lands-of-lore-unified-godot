#!/usr/bin/env python3
"""Extract the existing 31-entry reward threshold table from pinned original LOLG.DAT."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

EXE_SHA = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
TABLE_SHA = 'a059288b760bae3a5f0100800345a32bd8f2b434486cdecf6e49c5138a872eca'


def prepare(game, output):
    if output.exists():
        raise ValueError('Output must be a fresh directory')
    if output == game or output in game.parents or game in output.parents:
        raise ValueError('Output overlaps original game directory')
    exe = (game / 'LOLG.DAT').read_bytes()
    if hashlib.sha256(exe).hexdigest() != EXE_SHA:
        raise ValueError('Unsupported executable')
    u32 = lambda offset: struct.unpack_from('<I', exe, offset)[0]
    # Same LE object/page addressing used by verify_hive_sword_reward_application.
    le = 0x39024 + u32(0x39060)
    first = u32(le + u32(le + 0x40) + 108)
    address = 0xe810
    page = le + u32(le + 0x48) + (first - 1 + address // 4096) * 4
    if exe[page + 3] != 0:
        raise ValueError('Unsupported table page flags')
    position = 0x39024 + u32(le + 0x80) + (int.from_bytes(exe[page:page + 3], 'big') - 1) * 4096 + address % 4096
    raw = exe[position:position + 124]
    if hashlib.sha256(raw).hexdigest() != TABLE_SHA:
        raise ValueError('Reward threshold table differs')
    data = dict(version=1, thresholds=list(struct.unpack('<31I', raw)),
                executable_sha256=EXE_SHA, file_offset=position, table_sha256=TABLE_SHA)
    target = output / 'assets/lol2/generated/hive_reward_thresholds.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(data, indent=2) + '\n')
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        target = prepare(args.game.resolve(), args.output_root.resolve())
    except (ValueError, OSError, struct.error) as error:
        parser.error(str(error))
    print(f'PASS 31 source thresholds: {target}')


if __name__ == '__main__':
    main()
