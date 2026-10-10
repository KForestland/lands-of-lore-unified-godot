#!/usr/bin/env python3
"""Source evidence for the Prism on-hit blind adapter and its Museum panorama (docs/prism-effects.md).

- GLOBAL definition 7 "8-Prism" (identity 0xE50DCDD9) uses item handler 7; table slot 7 resolves to 0x965DC.
- Handler 7 (0x965DC) acts only on event 5. Event 5 is used only by the special melee weapon handlers (listed),
  so it is read as the melee on-hit event (inference). draw = 12415C(221D8, 1, 1000); the player's current
  region (helper pattern on player 0x22574: +0x15 bit 0x10 / +0xC) word +0x1C bit 0x200 set -> success when
  draw > 749 (~25%), clear -> draw > 249 (~75%). Success: pool object 0x5E, 107498(obj, attacker, target +0x46,
  target +0x36, mode 3). Failure: message E3924(23C68, definition word +0x37). Both return 0 (hit unchanged).
- 107498 builds vtable 0x7278 (slot +0x38 tick = 0x107A84). On frame 1 the tick shows message slot 0x134
  (mode != 2) and, when the bound target has +0x14 bit 0x4000, sends target vt+0x80 a packet: mode 3 ->
  {word0 0x1040, word2 1, +0x14 2, +0x15 0xF, +0x16 duration 0xA}. Duration unit not traced (read as 10 s).
- The Museum pickup group6590 op204 commands use decoder 0x64770 path "word+4 not -1/-2": wall record table
  [22D08] (8-byte records): word0 = descriptor, byte5 |= 0x40. The seven records keep 430..424 -> 871.
- Region word14 (+0x1C) bit 0x200 counts per area are derived from each pinned geometry entry; the exception
  regions (minority value) are written to scripts/lol2/prism_blind_regions.json as numeric polygons only.
Writes docs/prism-effect-checks.json and scripts/lol2/prism_blind_regions.json.
"""
import hashlib, json, struct
from pathlib import Path
from verify_hive_executioner import GAME, EXE_HASH, u32
from verify_special_pixel_table_binding import fixups
from prepare_museum_key_locks import definitions

ROOT = Path(__file__).resolve().parents[1]
LOL2_OUT = Path('/home/bob/lol2_out')
SPANS = {(0x965DC, 0x966E4): None, (0x107498, 0x107586): None, (0x107A84, 0x107C44): None, (0x647B3, 0x6484A): None}
# Byte checks inside the pinned spans: (address, bytes, meaning).
FACTS = [(0x965E7, '3c05', 'event 5 only'),
         (0x965F2, '68e80300006a0168d8210200e859db0800', 'draw = 12415C(221D8, 1, 1000)'),
         (0x96612, '813da17c0b0074250200', 'region helper: player class 0x22574 special case'),
         (0x96625, 'f6058925020010', 'region helper: player +0x15 bit 0x10'),
         (0x9664E, '668b401c', 'region word +0x1C'),
         (0x96657, 'f6c402', 'region flag bit 0x200'),
         (0x96664, '81faf9000000', 'flag clear: success when draw > 249'),
         (0x96670, '81faed020000', 'flag set: success when draw > 749'),
         (0x96682, '6a5e', 'pool object 0x5E'),
         (0x9669D, '6a03', 'effect mode 3'),
         (0x966AC, 'e8e70d0700', 'call 107498 effect constructor'),
         (0x966C6, '668b4037', 'failure message: definition word +0x37'),
         (0x966D5, 'e84ad20400', 'failure: E3924 message'),
         (0x1074BC, 'c7402878720000', 'effect vtable 0x7278'),
         (0x1074C3, '8a4524884658', 'mode byte +0x58 from argument'),
         (0x107ADF, '83f801', 'tick: frame 1'),
         (0x107B1D, '0534010000', 'message slot 0x134 (mode != 2)'),
         (0x107B47, '2500400000', 'target +0x14 bit 0x4000 required'),
         (0x107BCC, '83f803', 'mode 3 packet'),
         (0x107BD1, 'b940100000', 'packet word0 0x1040'),
         (0x107BD6, 'ba01000000', 'packet word2 1'),
         (0x107BDF, 'b90a000000', 'packet duration 0xA'),
         (0x107BF7, 'ff9280000000', 'target vt+0x80 status packet'),
         (0x647B3, '8b4302c1f81083f8ff', 'op204: word+4 == -1 region material'),
         (0x647EE, '83f8fe', 'op204: word+4 == -2 region byte'),
         (0x64821, '8b5302c1fa10a1082d0200c1e20301c2668b4b068a620566890a80cc40886205',
          'op204 otherwise: record [22D08]+8*word4: word0 = word6, byte5 |= 0x40')]
EVENT5 = ['8-Prism', '9-Firestorm', '16-Ax Traitor', '17-Drac dagger', '19-Blizzard', '22-Darkstorm']
COMMANDS = ['cc90e101cf066703', 'cc90e201d0066703', 'cc90e301eb066703', 'cc90bf01d1066703', 'cc90e401ec066703',
            'cc90e501d2066703', 'cc90e601d3066703']
AREAS = {'museum': 'museum_geometry_20260913', 'jungle': 'jungle_geometry_20260914', 'hive': 'hive_geometry_20260914',
         'cave': 'draracle_geometry_2026-09-11'}


def handler_address(exe, slot):
    le = 0x39024 + u32(exe, 0x39060); first = u32(exe, le + u32(exe, le + 0x40) + 108)
    s = 0xc860 + slot * 4
    rel = fixups(exe, le, first - 1 + s // 4096)[s % 4096]
    assert rel['target_object'] == 2
    return rel['target_offset'] + 0x59024, (lambda a: fixups(exe, le, first - 1 + a // 4096)[a % 4096]['target_offset'] + 0x59024)


def region_flags(name):
    g = json.loads((LOL2_OUT / AREAS[name] / 'geometry.json').read_text())
    src = g['source']; path = GAME / 'DAT' / Path(src['file']).name
    archive = path.read_bytes(); assert hashlib.sha256(archive).hexdigest() == src['sha256'], name
    rows, enclosed = [], 0
    for r in g['regions']:
        raw = bytes.fromhex(r['raw_hex']); assert archive[r['source_offset']:r['source_offset'] + 44] == raw, (name, r['id'])
        flag = bool(struct.unpack('<22H', raw)[14] & 0x200); enclosed += flag
        rows.append((r, flag))
    default = enclosed * 2 >= len(rows)
    vertices = g.get('vertices_fixed') or [[v['x_fixed'], v['y_fixed']] for v in g['vertices']]
    exceptions = []
    for r, flag in rows:
        if flag == default: continue
        poly = [[vertices[v][0] / 65536, -vertices[v][1] / 65536] for v in r['vertex_indices']]
        exceptions.append(dict(region=r['id'], polygon=poly, floor_min=min(r['floor_corners']), ceiling_max=max(r['ceiling_corners'])))
    return dict(archive=src['file'], archive_sha256=src['sha256'], regions=len(rows), flag_set=enclosed,
                default_enclosed=default, exceptions=exceptions)


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes(); assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    blob, base, n, names = definitions()
    d = blob[base + 7 * 91:base + 8 * 91]
    assert names[7] == '8-Prism' and u32(d, 24) == 0xE50DCDD9 and d[0x42] == 7
    address, dref = handler_address(exe, 7)
    assert address == 0x965DC
    for a, want, _ in FACTS: assert exe[a + 0x37000:a + 0x37000 + len(want) // 2].hex() == want, hex(a)
    spans = {hex(a): hashlib.sha256(exe[a + 0x37000:z + 0x37000]).hexdigest() for (a, z) in SPANS}
    assert dref(0x7278 + 0x38) == 0x107A84 and dref(0x7278 + 0xF0) == 0x1079C8
    # Every handler whose first event test is event 5.
    users = {}
    for i in range(n):
        di = blob[base + i * 91:base + (i + 1) * 91]
        if di[0x42]: users.setdefault(di[0x42], []).append(names[i])
    event5 = []
    for h, items in users.items():
        a, _ = handler_address(exe, h)
        head = exe[a + 0x37000:a + 0x37000 + 0x20]
        if b'\x3c\x05' in head and not any(b'\x3c' + bytes([e]) in head for e in (1, 6, 7, 0xa, 0xb, 0x10, 0x11)):
            event5 += items
    assert sorted(event5) == sorted(EVENT5), event5
    # Pickup op204 commands -> wall records; initial and target descriptors from the Museum geometry entry.
    source = json.loads((ROOT / 'scripts/lol2/museum_prism_source.json').read_text())
    assert [c['raw_hex'] for c in source['commands'][3:10]] == COMMANDS
    museum = json.loads((LOL2_OUT / AREAS['museum'] / 'geometry.json').read_text())
    archive = (GAME / 'DAT/L3_DH.MIX').read_bytes(); e = museum['source']['entry']
    raw = archive[e['offset']:e['offset'] + e['size']]
    assert hashlib.sha256(raw).hexdigest() == museum['source']['entry_sha256']
    wall_start, wall_count = u32(raw, 8), u32(raw, 0x54)
    records = []
    for c in COMMANDS:
        b = bytes.fromhex(c); region, record, descriptor = struct.unpack_from('<HhH', b, 2)
        assert b[0] == 204 and record not in (-1, -2) and record < wall_count
        r = raw[wall_start + record * 8:wall_start + record * 8 + 8]
        owner = museum['regions'][region]; words = struct.unpack('<22H', bytes.fromhex(owner['raw_hex']))
        assert words[13] <= record < words[13] + (words[15] & 255), (region, record)
        records.append(dict(region=region, wall_record=record, edge_code=r[5] & 31, initial_descriptor=struct.unpack_from('<h', r)[0],
                            new_descriptor=descriptor, raw_hex=r.hex()))
    assert [x['initial_descriptor'] for x in records] == [430, 429, 428, 427, 426, 425, 424] and {x['new_descriptor'] for x in records} == {871}
    areas = {k: region_flags(k) for k in AREAS}
    assert areas['museum']['default_enclosed'] and not areas['museum']['exceptions']
    assert areas['hive']['default_enclosed'] and areas['cave']['default_enclosed'] and not areas['jungle']['default_enclosed']
    table = dict(version=1, scope='Region +0x1C bit 0x200 per area (set = enclosed, Prism ~25%; clear = open, ~75%). '
                 'Only the minority regions are listed. Polygons are source x/-y; heights source floor/ceiling.',
                 thresholds=dict(draw_max=1000, enclosed_above=749, open_above=249),
                 areas={k: dict(default_enclosed=v['default_enclosed'], exceptions=v['exceptions']) for k, v in areas.items()})
    (ROOT / 'scripts/lol2/prism_blind_regions.json').write_text(json.dumps(table, separators=(',', ':')) + '\n')
    report = dict(executable_sha256=EXE_HASH,
                  definition=dict(index=7, name=names[7], identity=hex(u32(d, 24)), handler=7, failure_message_word=struct.unpack_from('<H', d, 0x37)[0]),
                  handler=dict(address='0x965DC', event=5, event5_items=sorted(event5), draw='12415C(221D8,1,1000)',
                               region_flag='player region word +0x1C bit 0x200', enclosed_success='draw > 749', open_success='draw > 249',
                               success='pool 0x5E, 107498(obj, attacker, target+0x46, target+0x36, 3)', failure='E3924 definition word +0x37'),
                  effect=dict(constructor='0x107498', vtable='0x7278', tick='0x107A84', remove='0x1079C8',
                              frame1='message slot 0x134; target +0x14 bit 0x4000 -> vt+0x80 packet',
                              packet_mode3=dict(word0='0x1040', word2=1, kind='2/0xF', duration='0xA (read as 10 s, inference)')),
                  spans=spans, facts={hex(a): m for a, _, m in FACTS},
                  panorama=dict(commands=COMMANDS, records=records),
                  region_flags={k: {x: v[x] for x in ('archive', 'archive_sha256', 'regions', 'flag_set', 'default_enclosed')} | dict(exceptions=len(v['exceptions']))
                                for k, v in areas.items()},
                  not_traced=['creature-side handling of packet 0x1040 (exact native blind behaviour)', 'duration unit of 0xA',
                              'message texts (slot 0x134, definition word +0x37)', 'pool 0x5E effect visual', '12415C distribution (assumed uniform)'],
                  passed=True)
    (ROOT / 'docs/prism-effect-checks.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS prism effect sources: definition7 handler7 slot, 4 spans, %d byte facts, event5 weapons %d, 7 op204 panorama records, region flags %s'
          % (len(FACTS), len(event5), {k: '%d/%d' % (v['flag_set'], v['regions']) for k, v in areas.items()}))


if __name__ == '__main__':
    main()
