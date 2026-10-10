#!/usr/bin/env python3
"""Source evidence for the Net of Exile on-hit adapter (docs/net-exile-onhit.md).

- GLOBAL definition 25 "26-Net of Exile" (identity 0x1EDB305A) uses item handler 104; table slot 104 resolves to 0x9B718.
- Handler 104 (0x9B718): only event 0x11 (17, hit) with a target (+0x15) whose class (vtable[0]) is 2: allocate pool
  object 0x7A and call 10E2F8(object, attacker +1, target +0x15, 0); returns 1. No other effect (no damage change).
- 10E2F8: base constructor 10C1E4 with family 4; +0x58=0x2A, +0x64=1, +0x54=0x400; unbound (+0x76 == 0): pool 0x5E visual
  only; bound: sound request, target class 0x22574 gets message 0x1A value 1, then lifetime +0x6E = 0xA0000 (10.0 in
  16.16; read as 10 s, an inference) and +0x14 bit 0x80 cleared.
Writes docs/net-exile-onhit-checks.json.
"""
import hashlib, json
from pathlib import Path
from verify_hive_executioner import GAME, EXE_HASH, u32
from verify_special_pixel_table_binding import fixups
from prepare_museum_key_locks import definitions

ROOT = Path(__file__).resolve().parents[1]
SPANS = {(0x9B718, 0x9B772): '5356578b5c24148a033c11740631c05f5e5bc38b531585d274f389d0508b5228ff1283c4043c0275e46a7a8b0d60f60d0051e81561000083c40885c074136a008b7315568b7b015750e8922b070083c410b8010000005f5e5bc3',
         (0x10E2F8, 0x10E442): '5356575589e583ec388b5d148b5520528b4d1c518b7518566a0453e8ccdeffff89c6c74028009b000089c38a405983c414a8020f8508010000c646582ab804000000c6466401c1e0088b7e766689465485ff753d8a665980cc026a5e886659a160f60d0050e80235f9ff83c40885c00f84cc0000006a018b763e31d257668b561e525650e82345ffff83c414e9b0000000f605c46902000175256a01a1cc6902006a0005a401000056668b0025ffff00005068683c0200e87055fdff83c414837b76007460817b3e7425020075576a366a008d45c850e8d1140400b602b10483c40c8b43768b733e8945cc8975d0895dd88875dc884dddba1a000000b904000000be01000000668955ca66894dc88975de8d55c88b4376528b702850ff968000000083c4088b7b7657e822d5f9ff8a6b14c7436e00000a0080e57f83c404886b1489d889ec5d5f5e5bc3'}
# Byte checks inside the pinned spans: (address, bytes, meaning).
FACTS = [(0x9B721, '3c11', 'event 0x11 only'), (0x9B73D, '3c02', 'target class 2'), (0x9B741, '6a7a', 'pool object 0x7A'),
         (0x10E310, '6a04', 'family 4'), (0x10E331, 'c646582a', '+0x58 = 0x2A'), (0x10E3BD, '817b3e74250200', 'class 0x22574'),
         (0x10E3EF, 'ba1a000000', 'message 0x1A'), (0x10E429, 'c7436e00000a00', 'lifetime +0x6E = 0xA0000')]


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes(); assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    for (a, z), want in SPANS.items(): assert exe[a + 0x37000:z + 0x37000].hex() == want, hex(a)
    for a, want, _ in FACTS: assert exe[a + 0x37000:a + 0x37000 + len(want) // 2].hex() == want, hex(a)
    le = 0x39024 + u32(exe, 0x39060); first = u32(exe, le + u32(exe, le + 0x40) + 108)
    slot = 0xc860 + 104 * 4
    rel = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
    assert rel['target_object'] == 2 and rel['target_offset'] + 0x59024 == 0x9B718
    blob, base, n, names = definitions()
    d = blob[base + 25 * 91:base + 26 * 91]
    assert names[25] == '26-Net of Exile' and u32(d, 24) == 0x1EDB305A and d[0x42] == 104
    report = dict(executable_sha256=EXE_HASH, definition=dict(index=25, name=names[25], identity=hex(u32(d, 24)), handler=104),
                  handler=dict(address='0x9B718', event=17, target_class=2, pool_object='0x7A', constructor='0x10E2F8'),
                  spans={hex(a): hashlib.sha256(bytes.fromhex(w)).hexdigest() for (a, _), w in SPANS.items()},
                  facts={hex(a): m for a, _, m in FACTS},
                  lifetime=dict(raw='0xA0000', reading='10.0 (16.16) -> 10 s hold (inference)'),
                  not_hosted=['pool 0x5E net visual', 'message 0x1A to class 0x22574', 'native sound request'], passed=True)
    (ROOT / 'docs/net-exile-onhit-checks.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS net exile on-hit sources: definition 25 handler104 slot, 0x9B718/0x10E2F8 spans, 8 byte facts')


if __name__ == '__main__':
    main()
