#!/usr/bin/env python3
"""Pin the Huline village alarm (control216 lifecycle and its archers) as a source contract and stage sound 403.

Every record, command group and predicate is read from the hash-checked L4_HJ archive and asserted byte for byte.
Native facts (LOLG.DAT, static; file offset = address + 0x37000):
- op14 (B47B4): byte4 = operation, byte5 = argument, byte6 = the owner's nth kind2 record. Operation3 (B485C) starts
  a stopped timer; a nonzero argument redraws its countdown. No op14 stop on controls 77/216/217 exists in L4_HJ.
- op15 control→object (table 0x5C878 → B5C82): byte5/word6 name the second object (kind1 0 = player); byte4 indexes
  0x5C6B4. Case 93 (B62A4) pool-allocates 0x72 bytes and calls F7030(obj, control, player target, 7). That is
  FB838(obj, 0x5B, definition 12, owner = control), vtable 0x980C. Mode 7 (table 0x9DFD0 → F70A8) gives +0x58 = 3 and
  speed 0xFA00000. SPELL.ODF definition 12 is "Arrow" (name table at ds+0xEB6C).
- op20 (B5BDC): E3924(0x23C68, word+4, object, ...) plays sound-bank request word+4 at the object.
- op9 properties (B50C0, table 0x5C010): 2/3 unlink/link, 9/10 set/clear [+0x16] bit1, 13/14 clear/set [+0x15] 0x80,
  17 sets [+0x15] 0x40, 21 raises event20.
- Movable motion (63740/63890) raises event 15 or 16 at its travel ends, then 17.
"""
import hashlib, json, struct, sys
from pathlib import Path
from build_game_atlas import parse_mix, section, u32
from audit_game_actor_scripts import groups
from audit_game_transition_owners import GAME, collect_owners
from prepare_jungle_exit_encounter import predicate
from prepare_creature_audio_clips import stage_clips, sound_bank
import prepare_jungle_bacatta as B
ROOT = Path(__file__).resolve().parents[1]
ARCHERS, ALARM, SOUND_OBJECT, REGION = (77, 216, 217), 216, 510, 3805
# (stream, group): commands, byte for byte.
EXPECTED_GROUPS = {
    (0, 7956): ['020100002500', '0e10d80003000100', 'd20000000012'],
    (1, 27162): ['1403fe01930180003225'],
    (1, 27172): ['c60000003401', '091064001500', 'ce00000000fe', '09204f001100', '09204e001100', '01204b000000', '01204a000000',
                 '0e10d80003000000', '012038006400', '012039006400', '01204e000000', '01204f000000', 'c60000000702', 'c6000000081e',
                 '0d0240000d000000', '0d02400007000000', '0e104d0003000000', '0e10d90003000000', '0e10d80003000200', 'c60000002001',
                 '051052000000'],
    (1, 27316): ['0f10d8005d010000'],
    (1, 18758): ['0f104d005d010000'],
    (1, 27324): ['0f10d9005d010000'],
    (1, 21372): ['c60000003401', 'c70000001d01', 'c6000000081e', '090240000300', '0d0240000d000000', '0d02400007000000'],
    (1, 21418): ['090240001100', '0802400001000000', '0d0240000d000000', '0d02400007000000', 'c70000001d01'],
    (1, 28168): ['0e104d0003000000', '0e10d80003020000', '0e10d90003000000'],
    (1, 18846): ['01204e000000', '01204f000000'],
    (1, 18864): ['c590e30e0000', 'c590dd0e0000', '01204e006400', '01204f006400'],
}
# Records this owner runs: (owner_kind, owner, kind, value, group).
OWNED = [('region', 3805, 2, 0, 7956), ('control', 216, 2, 304, 27162), ('control', 216, 2, 304, 27172), ('control', 216, 2, 272, 27316),
         ('control', 77, 2, 272, 18758), ('control', 217, 2, 272, 27324), ('control', 100, 6, 20, 21372), ('control', 100, 6, 20, 21418),
         # Control82 is an invisible logic marker (assembly template36, resource 0/type 0, no movie): an op5 selector ends at once into kind3 value=selector.
         ('control', 82, 3, 0, 18846), ('control', 82, 3, 1, 18864)]
# Records naming these objects that belong to other owners, or that are reported without a producer.
OTHER = {('prop', 482, 6, 20, 10162): 'Bacatta57 (arms control216 index1 through its effects hook)',
         ('movable', 79, 6, 16, 28168): 'reported: re-arms the timers g27172 already starts; no separate producer',
         ('region', 3805, 2, 0, 7950): 'Left_Village local36 2->3 (monastery room bank; not run here)'}

def main():
    inventory = json.loads((ROOT / 'docs/game-source-inventory.json').read_text())
    area = next(a for a in inventory['areas'] if a['id'] == 'L4_HJ')
    archive = (GAME / area['source']['file']).read_bytes(); assert hashlib.sha256(archive).hexdigest() == area['source']['sha256']
    entry = next(e for e in parse_mix(archive) if e['key'] == area['source']['geometry_key'])
    raw = archive[entry['offset']:entry['offset'] + entry['size']]; assert hashlib.sha256(raw).hexdigest() == area['source']['geometry_sha256']
    owners, _ = collect_owners(raw, entry['offset'], area['counts']['regions'])
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    parsed = {}
    for stream, (of, sf) in enumerate([(0x3c, 0x84), (0x44, 0x8c)]):
        _, _, blob = section(raw, of, sf, 1)
        for group, commands in groups(blob): parsed[(stream, group)] = [body.hex() for _, body in commands]
    for key, expected in EXPECTED_GROUPS.items(): assert parsed[key] == expected, (key, parsed[key])
    by_key = {(o['owner_kind'], o['owner'], o['event'], o['value'], o['group']): o for o in owners}
    # Completeness: every record whose group starts or names a timer of controls 77/216/217, or that is owned by
    # region3805, is owned here or attributed above.
    timer_names = ('104d00', '10d800', '10d900')
    seen = {k for k, o in by_key.items() if any(c[:2] == '0e' and c[2:8] in timer_names for c in parsed[(o['stream'], o['group'])])
            or (k[0], k[1]) in (('region', REGION), ('control', 77), ('control', 216), ('control', 217))}
    assert seen <= set(OWNED) | set(OTHER), sorted(seen - set(OWNED) - set(OTHER))
    records = []
    for key in OWNED:
        o = by_key[key]; n = archive[o['archive_offset']]
        records.append(dict(owner_kind=key[0], owner=key[1], kind=key[2], value=key[3], stream=o['stream'], group=key[4], predicate=o['predicate'],
                            archive_offset=o['archive_offset'], raw=archive[o['archive_offset']:o['archive_offset'] + n].hex(), commands=parsed[(o['stream'], key[4])]))
    predicates = {}
    def add(p):
        if p is None or str(p) in predicates: return
        e = predicate(table, p); predicates[str(p)] = e
        for side in (e['left'], e['right']):
            if 'predicate' in side: add(side['predicate'])
    for r in records: add(r['predicate'])
    assert sorted(predicates, key=int) == ['49', '85', '166', '183', '192'], sorted(predicates)
    # Timer rows in each control's kind2 record order (op14 byte6 selects by ordinal).
    timers = {}
    for c in ARCHERS:
        rows = [o for o in owners if o['owner_kind'] == 'control' and o['owner'] == c and o['event'] == 2]
        timers[str(c)] = []
        for i, o in enumerate(rows):
            b = archive[o['archive_offset']:o['archive_offset'] + archive[o['archive_offset']]]
            timers[str(c)].append(dict(ordinal=i, group=o['group'], flags=b[5], range=[b[7], b[6]], remaining=struct.unpack_from('<H', b, 8)[0],
                                       predicate=o['predicate'], raw=b.hex()))
    assert [(t['group'], t['flags'], t['range'], t['remaining']) for t in timers['216']] == [(27162, 1, [0, 5], 300), (27172, 1, [0, 5], 300), (27316, 1, [2, 5], 240)], timers['216']
    assert [(t['group'], t['remaining']) for t in timers['77']] == [(18758, 300)] and [(t['group'], t['remaining']) for t in timers['217']] == [(27324, 120)], timers
    # Positions: archer controls, the sound object and the gate passage.
    _, _, controls = section(raw, 0x18, 0x64, 33); _, _, props = section(raw, 0x14, 0x60, 37)
    def row(blob, stride, i):
        r = blob[i * stride:(i + 1) * stride]; x, z, h, y = struct.unpack_from('<hhHh', r, 0)
        return dict(id=i, position=[x, y, -z], heading=h, flags=struct.unpack_from('<H', r, 8)[0])
    archers = {str(c): row(controls, 33, c) for c in ARCHERS}
    assert [archers[k]['position'] for k in ('77', '216', '217')] == [[-1668, 0, -4300], [-1414, 0, -5369], [-1416, 0, -5129]]
    sound_object = row(props, 37, SOUND_OBJECT); assert sound_object['position'] == [-2024, 10, -4881]
    geometry = json.loads(B.GEOMETRY.read_text())
    reg = geometry['regions'][REGION]; assert reg['id'] == REGION
    region = dict(region=REGION, polygon=[[geometry['vertices_fixed'][v][0] / 65536, -geometry['vertices_fixed'][v][1] / 65536] for v in reg['vertex_indices']],
                  floor_min=min(reg['floor_corners']), floor_max=max(reg['floor_corners']))
    assert region['polygon'] == [[-1447, -5329], [-1376, -5329], [-1376, -5169], [-1448, -5169]]
    # Local names (geometry +0xB0 count, +0xB4 initials, then 41-byte names): the locals these groups touch.
    count, at = u32(raw, 0xb0), u32(raw, 0xb4)
    names = {n: raw[at + count + n * 41:at + count + n * 41 + 41].split(b'\0')[0].decode() for n in (7, 8, 32, 33, 52)}
    assert names == {7: 'Has_Luther_had_drunken_encounter', 8: 'Kelsrick_trigger', 32: 'Close_Gates_when_Huline_Alert_triggered', 33: 'Anyar_Attacked', 52: 'Kelsrick_Attacked'}
    # The Arrow definition (SPELL.ODF 12) and sound request 403.
    from audit_monastery_rooms import extract
    spell, _ = extract((GAME / 'GLOBAL.MIX').read_bytes(), 'GLOBAL\\SPELL.ODF')
    assert hashlib.sha256(spell).hexdigest() == '3b2ae70b61a2211d7ffc3358971c54509ee71c3435ce3eca347b20502b5e605e'
    arrow = spell[412 + 12 * 87:412 + 13 * 87]
    assert b'Arrow' in spell[412 + 18 * 87:]
    game = GAME
    bank = sound_bank(game); rcount, rtable = struct.unpack_from('<II', bank, 0x258)
    sound_name = bank[rtable + 403 * 60 + 16:rtable + 404 * 60].split(b'\0')[0].decode()
    stage_clips(ROOT, 'jungle_village_alarm/sounds', [403], {403: sound_name}, game=game)
    wav = ROOT / 'assets/lol2/generated/jungle_village_alarm/sounds/403.wav'
    result = dict(version=1, source=area['source'], region=region, records=records, predicates=predicates, timers=timers,
                  archers=archers, sound_object=sound_object, sound=dict(request=403, name=sound_name, wav_sha256=hashlib.sha256(wav.read_bytes()).hexdigest()),
                  arrow=dict(definition=12, name='Arrow', raw=arrow.hex(), constructor='F7030 mode7: +0x58=3, speed 0xFA00000'),
                  local_names={str(k): v for k, v in names.items()}, owned_locals=[7], kelsrick_locals=[8, 32, 33, 52],
                  movables={'gates': [78, 79], 'inner': [74, 75], 'doors': [56, 57]},
                  other_records={f'{k[0]}{k[1]}/{k[2]}/{k[3]}/g{k[4]}': v for k, v in OTHER.items()})
    (ROOT / 'scripts/lol2/jungle_village_alarm_source.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS village alarm source: {len(records)} records, predicates {sorted(predicates, key=int)}, timers 216x3/77/217, archers {[archers[k]["position"] for k in archers]}, sound 403 {sound_name}')

if __name__ == '__main__':
    main()
