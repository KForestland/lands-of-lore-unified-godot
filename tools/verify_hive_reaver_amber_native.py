#!/usr/bin/env python3
"""Native evidence for the Hive Reaver collapse and items (docs/hive-reaver-amber.md); pinned LOLG.DAT code spans.

- 649B3: opcode 0xC4 (196) branches to the region-surface handler (6484A -> 64DDC).
- 64DDC: command byte6 bit0 picks the ceiling (+0x16) or floor (+0x14) height; bit3 makes the value relative.
- On a move start it raises region event (dir<=0) for the floor or (dir<=0)+2 for the ceiling, then 12 / 13.
- On completion (651DA) it raises 4/5 (floor up/down) or 6/7 (ceiling up/down), then 16 / 17.
- F2FC0 walks the region's record list for kind 0x0B records whose region word and byte6 match the event.
- 6507B: the per-step change is speed*10/4 * [0x22C54] / 60 (16.16 accumulation).
- Item handler 18 ("18-Reaver of GO"): event10 sets player byte 0x2270E bit3, event11 clears it.
"""
import hashlib, json
from pathlib import Path
from verify_hive_executioner import GAME, EXE_HASH, u32
from verify_special_pixel_table_binding import fixups

ROOT = Path(__file__).resolve().parents[1]
SPANS = {
    (0x649b3, 0x649bb): '3cc40f848ffeffff',
    (0x64fba, 0x64fe3): '8a4306a80174058b5714eb038b5712c1fa108a4306a8087406668b4304eb06668b430429d06689430a',
    (0x64fee, 0x65068): '8a4306a80174378b4308c1f81085c00f9ec00402804f28800fbec05057e8b0df080083c4088a57286a0d80ca8057885728e89cdf080083c408e9a30100008b43088a4f28c1f81080c94085c00f9ec0884f2825ff0000005057e874df080083c4088a6f286a0c80cd4057886f28e860df080083c408e967010000',
    (0x651da, 0x6524f): '8a4306a8017435837df8007e0e8a67286a0680e47f57886728eb0b8a47286a07247f57884728e8bbdd080083c4088a57286a1180e27f57885728eb34837df8007e0e8a4f286a0480e1bf57884f28eb0c8a77286a0580e6bf57887728e885dd080083c4088a6f286a1080e5bf57886f28e871dd0800',
    (0xf3015, 0xf303f): '8a530180fa0b0f85ad00000031c0668b430489df39c50f859d0000008b4c241531c0c1f9188a430639c1',
    (0x972af, 0x972d1): '8a150e27020080ca08b80100000088150e270200c380250e270200f7b801000000c3',
    (0x972d4, 0x972e7): '8b4424088a003c0a720676cf3c0b74e031c0c3',
    (0x6507b, 0x650b5): '8a630784e4744b31d288e28d04950000000001c201d289d0c1fa1fc1e2021bc2c1f8028b35542c020089f20fafd0be3c00000089d0c1fa1ff7fe',
}


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes(); assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    for (a, z), want in SPANS.items():
        assert exe[a + 0x37000:z + 0x37000].hex() == want, hex(a)
    # 6484A calls the handler 64DDC.
    assert exe[0x6484c + 0x37000] == 0xe8 and (0x6484c + 5 + int.from_bytes(exe[0x6484d + 0x37000:0x64851 + 0x37000], 'little', signed=True)) == 0x64ddc
    le = 0x39024 + u32(exe, 0x39060); first = u32(exe, le + u32(exe, le + 0x40) + 108)
    rel = fixups(exe, le, first - 1 + (0xc860 + 18 * 4) // 4096)[(0xc860 + 18 * 4) % 4096]
    assert rel['target_object'] == 2 and rel['target_offset'] + 0x59024 == 0x972d4
    report = dict(executable_sha256=EXE_HASH, spans={hex(a): hashlib.sha256(bytes.fromhex(w)).hexdigest() for (a, _), w in SPANS.items()},
                  op196=dict(dispatch='649B3 -> 6484A -> 64DDC', byte6_bit0='ceiling (1) / floor (0)', byte6_bit3='relative', byte7='speed'),
                  region_events=dict(start={'floor_up': 0, 'floor_down': 1, 'ceiling_up': 2, 'ceiling_down': 3, 'then': [12, 13]},
                                     end={'floor_up': 4, 'floor_down': 5, 'ceiling_up': 6, 'ceiling_down': 7, 'then': [16, 17]},
                                     dispatcher='F2FC0: kind 0x0B records, region word +4, event byte +6'),
                  reaver_handler=dict(index=18, address='0x972D4', equip='event10 sets 0x2270E bit3', unequip='event11 clears it'), passed=True)
    (ROOT / 'docs/hive-reaver-amber-native-checks.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS hive reaver/amber native: op196 fields, region event numbering and kind11 dispatch, speed step, handler18 equip flag')


if __name__ == '__main__':
    main()
