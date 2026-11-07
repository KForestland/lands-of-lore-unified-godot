#!/usr/bin/env python3
"""Dump the original's movie name table (opcode 21 operand) from LOLG.DAT to scripts/lol2/movie_table.json.
Grok backlog 3 item 1 (2026-10-31): opcode 21's command byte 4 is a signed index into the dword table at encoded 0xE568
(PROVEN); the count is the image dword at encoded 0xE740 (85); each dword is an encoded object-5 pointer to a terminated
name, which the format "%s.vqa" at encoded 0x2C88 completes (the difference arm, taken by every Act 1 command). Object-5
encoded addresses are LOLG.DAT file offsets plus 0x1C1024 (witness: the count dword at file 0x1CF764 and the format bytes
25 73 2e 76 71 61 00 at file 0x1C3CAC, both in the report). What the named movie means in play stays UNKNOWN.
Usage: prepare_movie_table.py --game GAME_ROOT [--out scripts/lol2/movie_table.json]
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOLG_SHA256 = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
OBJECT5_BASE = 0x1C1024
TABLE, COUNT, FORMAT = 0xE568, 0xE740, 0x2C88


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--out', type=Path, default=ROOT / 'scripts/lol2/movie_table.json')
    a = p.parse_args()
    blob = (a.game / 'LOLG.DAT').read_bytes()
    if hashlib.sha256(blob).hexdigest() != LOLG_SHA256:
        sys.exit('LOLG.DAT is not the pinned image')
    count = struct.unpack_from('<I', blob, COUNT + OBJECT5_BASE)[0]
    fmt = blob[FORMAT + OBJECT5_BASE:FORMAT + OBJECT5_BASE + 7]
    if count != 85 or fmt != b'%s.vqa\0':
        sys.exit('table witnesses differ: count %d, format %r' % (count, fmt))
    entries = []
    for i in range(count):
        ptr = struct.unpack_from('<I', blob, TABLE + OBJECT5_BASE + 4 * i)[0]
        off = ptr + OBJECT5_BASE
        name = blob[off:blob.index(b'\0', off)].decode('latin1')
        entries.append(dict(index=i, name=name, file=name + '.vqa', pointer=ptr, name_file_offset=off))
    out = dict(version=1, source='LOLG.DAT', sha256=LOLG_SHA256, count=count, table_file_offset=TABLE + OBJECT5_BASE,
               count_file_offset=COUNT + OBJECT5_BASE, format='%s.vqa', object5_base=OBJECT5_BASE, entries=entries,
               scope='Opcode 21 operand table (Grok backlog3 item1, PROVEN index path). Names only; which player, scene or '
                     'effect each movie has in play is UNKNOWN. The ss- prefixed arm (bytes 73 73 2d) is not taken by any Act 1 command.')
    a.out.write_text(json.dumps(out, indent=1) + '\n')
    print('PASS movie table: %d names at LOLG.DAT file %#x -> %s' % (count, TABLE + OBJECT5_BASE, a.out))


if __name__ == '__main__':
    main()
