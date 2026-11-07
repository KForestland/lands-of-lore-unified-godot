#!/usr/bin/env python3
"""Source evidence for Fire crystal use and the Museum sconce recharge (docs/fire-crystal.md).

- GLOBAL definitions 57 "57a-Fire crstl" (identity 0xE7B89177, handler2) and 58 "57b-Fire brnt" (0xDDC02377, handler0).
- Handler slot 2 resolves to 0x96080: only event1; decrements item byte +4 when nonzero; target search E11C8 and pool
  object 0x6E spawn; when byte +4 is 0, the held item is replaced by the item built from a runtime definition entry
  (identity at +0x18 of the 91-byte record) and the old one released (77ACC).
- All 23 Museum sconce controls 117..139 carry one kind4 mode3 record at owner state1 holding 57b: op2 player 0x18 and
  op3 "57a-Fire crstl" property1 (museum_key_locks_source.json, pinned by prepare_museum_key_locks.py).
- The MAGIC room grants "57a-Fire crstl" with property4 (magic_shop.gd give_item effects, pinned from the room DLL).
- Museum prop297 hit groups6692/6720/6748 reveal placed items6/5/4 through op9 kind4 property3.
  Each original placed item has identity0xDDC02377, definition58 (burnt crystal). A grant-only census missed this producer.
  Native hit admission and ordinary player reachability are separate verification requirements.
Writes docs/fire-crystal-checks.json.
"""
import hashlib, json, re
from pathlib import Path
from verify_hive_executioner import GAME, EXE_HASH, u32
from verify_special_pixel_table_binding import fixups
from prepare_museum_key_locks import definitions

ROOT = Path(__file__).resolve().parents[1]
SPANS = {(0x96080, 0x960b9): '53568b5c240c8b4424108a003c01740531c05e5bc38a630484e4740788e228c2885304680000000368a4270200e816b1040083c40885c074d9',
         (0x960e4, 0x96129): '807b0400753fa1046909008b0005880000008b40046bd05ba1f42c02008b4402185068d82c02008b1d573c0200e8468a000083c4085368483302008903e8a619feff83c408'}


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes(); assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    for (a, z), want in SPANS.items(): assert exe[a + 0x37000:z + 0x37000].hex() == want, hex(a)
    le = 0x39024 + u32(exe, 0x39060); first = u32(exe, le + u32(exe, le + 0x40) + 108)
    rel = fixups(exe, le, first - 1 + (0xc860 + 2 * 4) // 4096)[(0xc860 + 2 * 4) % 4096]
    assert rel['target_object'] == 2 and rel['target_offset'] + 0x59024 == 0x96080
    blob, base, n, names = definitions()
    d57 = blob[base + 57 * 91:base + 58 * 91]; d58 = blob[base + 58 * 91:base + 59 * 91]
    assert names[57] == '57a-Fire crstl' and u32(d57, 24) == 0xE7B89177 and d57[0x42] == 2
    assert names[58] == '57b-Fire brnt' and u32(d58, 24) == 0xDDC02377 and d58[0x42] == 0
    sconces = json.loads((ROOT / 'scripts/lol2/museum_key_locks_source.json').read_text())['sconces']
    assert sorted(int(k) for k in sconces) == list(range(117, 140))
    for k, v in sconces.items():
        r = v['recharge']
        assert r['mode'] == 3 and r['held_identity'] == 0xDDC02377 and r['predicate_expression']['raw'] == '0005000001', k
        assert r['commands'] == ['020100001800', '030100007791b8e701000000'], k
    shop = (ROOT / 'scripts/lol2/magic_shop.gd').read_text()
    grants = re.findall(r'\["give_item","57a-Fire crstl",(\d+)\]', shop)
    assert grants == ['4', '4', '4'], grants
    from verify_actor_item_grants import source_area
    area, arc, entry, geo, owners, streams = source_area('L3_DH')
    placed = []
    for item, group in [(6,6692),(5,6720),(4,6748)]:
        owner = next(o for o in owners if o['owner_kind']=='prop' and o['owner']==297 and o['event']==9 and o['group']==group)
        commands = [c['raw_hex'] for c in streams[1][group]]
        assert commands[-1] == '0904%02x000300' % item
        offset = u32(geo,0x20) + item*37
        raw = geo[offset:offset+37]
        assert u32(raw,32)==0xDDC02377
        placed.append(dict(item=item,group=group,command=commands[-1],archive_offset=entry['offset']+offset,placement_hex=raw.hex(),identity='0xddc02377',definition=58))
    report = dict(executable_sha256=EXE_HASH, handler=dict(index=2, address='0x96080', spans={hex(a): hashlib.sha256(bytes.fromhex(w)).hexdigest() for (a, _), w in SPANS.items()}),
                  definitions={'57': dict(name=names[57], identity=hex(u32(d57, 24)), handler=2), '58': dict(name=names[58], identity=hex(u32(d58, 24)), handler=0)},
                  sconce_recharge=dict(controls='117..139', records=23, held='57b-Fire brnt', grant='57a-Fire crstl', property=1),
                  shop=dict(grants=3, property=4),
                  burnout_definition='runtime entry ([0x96904]->+0x88+4 -> 91-byte record identity); 57b by the 57a/57b pairing (inference)',
                  placed_burnt_crystals=placed, act1_reachability='Museum prop297 hit groups reveal three placed burnt crystals (items6/5/4); previous grant-only census omitted placed-item activation. Native hit admission, actual pickups and sconce route still require verification.', passed=True)
    (ROOT / 'docs/fire-crystal-checks.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS fire crystal sources: handler2 spans, definitions 57/58, 23 sconce recharge records, shop property4 x3, three Museum placed burnt crystals')


if __name__ == '__main__':
    main()
