"""Reproduce the pinned rotation table from the supported original executable.

Original initializer constants were mapped through the LE initialized-data pages.
The historical host-x87/libm comparison agreed for all 4096 entries. This helper
retains the exact resulting table hash; unsupported hosts fail instead of silently
changing UVs. It does not claim live guest floating-point equivalence.
"""
import argparse
import hashlib
import math
from pathlib import Path
import struct

EXE_SHA256 = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
TABLE_SHA256 = 'd7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'
# LE object offsets 0x344c and 0x3454, mapped in the supported executable only.
STEP_FILE_OFFSET = 1852528
SCALE_FILE_OFFSET = 1852536


def rotation_table(game_root):
    raw = (Path(game_root) / 'LOLG.DAT').read_bytes()
    if hashlib.sha256(raw).hexdigest() != EXE_SHA256:
        raise ValueError('Original executable does not match the supported LOLG.DAT')
    step = struct.unpack_from('<d', raw, STEP_FILE_OFFSET)[0]
    scale = struct.unpack_from('<d', raw, SCALE_FILE_OFFSET)[0]
    values = [math.trunc(math.sin(i * step) * scale) for i in range(4096)]
    table = struct.pack('<4096i', *values)
    if hashlib.sha256(table).hexdigest() != TABLE_SHA256:
        raise ValueError('Generated rotation table differs from the supported table')
    return table


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True, help='fresh binary output file')
    args = parser.parse_args()
    table = rotation_table(args.game_root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open('xb') as stream:
        stream.write(table)
    print(f'4096 rotation entries verified: {TABLE_SHA256}')


if __name__ == '__main__':
    main()
