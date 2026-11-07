#!/usr/bin/env python3
"""Dump the original's room-archive stem table (opcode 12 operand) from LOLG.DAT to scripts/lol2/room_stems.json.
Grok backlog 6 item 1c (2026-10-31): opcode 12 passes its command byte 4 to 0xED6D0 -> 0xED470, which selects the dword at
[index*4 + encoded 0xEA6C] (an object-5 pointer to a stem cstring such as `settle1_`), cuts the stem at its first `_`, appends
the cstring at encoded 0x31BC (".mix") and, for an index below 46, ORs 2 into the byte at encoded 0x269C4 (PROVEN path with two
unread gates: bit 25 of the dword at 0x2279A and the byte at 0xB860). Object-5 encoded addresses are LOLG.DAT file offsets plus
0x1C1024 (the movie table's witness; here slot 39 = object-5 0x3404 at file 0x1C4428 `settle1_`, LOLG 0x1CFB2C `04340000`).
Grok backlog 6 item 15 names two more stems, `magic_` and `wpnext_`. What a room archive does in play stays UNKNOWN.
Usage: prepare_room_stems.py --game GAME_ROOT [--out scripts/lol2/room_stems.json]
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOLG_SHA256 = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
OBJECT5_BASE = 0x1C1024
TABLE, SUFFIX, COUNT = 0xEA6C, 0x31BC, 46


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--out', type=Path, default=ROOT / 'scripts/lol2/room_stems.json')
    a = p.parse_args()
    blob = (a.game / 'LOLG.DAT').read_bytes()
    if hashlib.sha256(blob).hexdigest() != LOLG_SHA256:
        sys.exit('LOLG.DAT is not the pinned image')
    suffix = blob[SUFFIX + OBJECT5_BASE:SUFFIX + OBJECT5_BASE + 5]
    if suffix != b'.mix\0':
        sys.exit('suffix witness differs: %r' % suffix)
    entries = []
    for i in range(COUNT):
        ptr = struct.unpack_from('<I', blob, TABLE + OBJECT5_BASE + 4 * i)[0]
        off = ptr + OBJECT5_BASE
        if off <= 0 or off >= len(blob):
            sys.exit('slot %d points outside the image (%#x)' % (i, ptr))
        stem = blob[off:blob.index(b'\0', off)].decode('latin1')
        archive = (stem.split('_')[0] if '_' in stem else stem) + '.mix'
        entries.append(dict(index=i, stem=stem, archive=archive.upper(), pointer=ptr, stem_file_offset=off))
    if entries[39]['stem'] != 'settle1_':
        sys.exit('slot 39 witness differs: %r' % entries[39]['stem'])
    out = dict(version=1, source='LOLG.DAT', sha256=LOLG_SHA256, count=COUNT, table_file_offset=TABLE + OBJECT5_BASE,
               suffix_file_offset=SUFFIX + OBJECT5_BASE, object5_base=OBJECT5_BASE, entries=entries,
               scope='Opcode 12 operand table (Grok backlog 6 item 1c, PROVEN index path, 46 slots; the archive name is the stem '
                     'cut at its first underscore plus .mix, as 0xED470 builds it). Which room each archive opens in play is UNKNOWN.')
    a.out.write_text(json.dumps(out, indent=1) + '\n')
    print('PASS room stems: %d stems at LOLG.DAT file %#x -> %s; 39 = %s' % (COUNT, TABLE + OBJECT5_BASE, a.out, entries[39]['stem']))


if __name__ == '__main__':
    main()
