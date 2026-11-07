#!/usr/bin/env python3
"""Check the native script export against Grok's G95 mechanism report and print host coverage.

    python3 tools/verify_native_scripts.py [--scripts-root DIR] [--game GAME_ROOT] [--coverage]

1. Every "Included groups" row of G95 REPORT.md (doors, slots, chains, traps, museum orb panel) must
   match the export: stream, group, group file offset, opcode list, owner object, record kind and
   record file offset. Includes movables 56/57, Spy Slider controls 1015/1013/236 and prop 232 of
   L7_DH (for example group 13798 at file 4874205).
2. Every HOST_CONTRACT.md row's command (archive file offset + hex) must be a command in the export.
3. With --game, the producer runs twice into fresh temporary directories and both runs must be
   byte-identical, and identical to the files under --scripts-root.
4. --coverage prints, per area, how many event-owned groups scripts/lol2/native_script_host.gd could
   run on PROVEN paths only and with its adapters (a static mirror of its handlers).
Exits 0 and prints PASS only when every check holds.
"""
import argparse
import hashlib
import json
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = 'scripts/lol2/native_scripts'

# (area, stream, group, group file offset, opcodes, owner ref, record kind, record file offset), REPORT.md verbatim.
G95_GROUPS = [
    ('L7_DH', 1, 13554, 4873961, [1, 16], 'movable:56', 4, 4883815),
    ('L7_DH', 1, 13572, 4873979, [1, 16], 'movable:56', 4, 4883829),
    ('L7_DH', 1, 13590, 4873997, [20, 5], 'movable:56', 9, 4883843),
    ('L7_DH', 1, 13612, 4874019, [20, 5], 'movable:56', 9, 4883853),
    ('L7_DH', 1, 13634, 4874041, [9, 198, 16, 20, 5, 1], 'movable:56', 9, 4883863),
    ('L7_DH', 1, 13680, 4874087, [20, 198], 'movable:56', 6, 4883873),
    ('L7_DH', 1, 13702, 4874109, [1, 16], 'movable:57', 4, 4883885),
    ('L7_DH', 1, 13720, 4874127, [1, 16], 'movable:57', 4, 4883899),
    ('L7_DH', 1, 13738, 4874145, [20, 16], 'movable:57', 4, 4883913),
    ('L7_DH', 1, 13760, 4874167, [15], 'movable:57', 8, 4883927),
    ('L7_DH', 1, 13774, 4874181, [5], 'movable:57', 9, 4883933),
    ('L7_DH', 1, 13786, 4874193, [5], 'movable:57', 9, 4883943),
    ('L7_DH', 1, 13798, 4874205, [198, 20, 5, 1], 'movable:57', 9, 4883953),
    ('L7_DH', 1, 13832, 4874239, [20], 'movable:57', 9, 4883963),
    ('L7_DH', 1, 13848, 4874255, [20], 'movable:57', 5, 4883977),
    ('L7_DH', 1, 7656, 4868063, [14, 16, 5, 9], 'control:84', 6, 4880071),
    ('L7_DH', 0, 76, 4949116, [1, 16], 'region:83', 12, 4950200),
    ('L7_DH', 0, 794, 4949834, [20, 1, 16, 18, 13, 13], 'region:1338', 12, 4950516),
    ('L7_DH', 1, 15750, 4876157, [16], 'actor:73', 6, 4883587),
    ('L5_HC', 1, 9776, 5902107, [1], 'movable:80', 6, 5907273),
    ('L7_DH', 1, 12424, 4872831, [20, 16], 'control:1015', 4, 4882223),
    ('L7_DH', 1, 12446, 4872853, [20, 16], 'control:1015', 4, 4882237),
    ('L7_DH', 1, 12380, 4872787, [20, 16], 'control:1013', 4, 4882193),
    ('L7_DH', 1, 12402, 4872809, [20, 16], 'control:1013', 4, 4882207),
    ('L7_DH', 1, 7744, 4868151, [9, 20, 16], 'control:236', 4, 4880091),
    ('L7_DH', 1, 7772, 4868179, [9, 20, 16], 'control:236', 4, 4880105),
    ('L7_DH', 1, 1568, 4861975, [9, 6, 198, 1, 1, 1, 1, 5, 7, 20], 'prop:232', 4, 4877189),
    ('L7_DH', 1, 1638, 4862045, [9, 18, 18, 18, 18, 198, 5, 7, 20], 'prop:232', 4, 4877203),
    ('L7_DH', 1, 1750, 4862157, [1, 1, 1, 1, 20, 20, 198], 'prop:232', 4, 4877217),
    ('L7_DH', 1, 1806, 4862213, [208, 9, 1, 1, 1, 1, 20, 198], 'prop:232', 4, 4877231),
    ('L5_HC', 1, 9782, 5902113, [19], 'movable:81', 5, 5907281),
    ('L5_HC', 1, 9792, 5902123, [19], 'movable:82', 5, 5907289),
    ('L5_HC', 1, 9802, 5902133, [19], 'movable:83', 5, 5907297),
    ('L5_HC', 1, 9812, 5902143, [19], 'movable:84', 5, 5907305),
    ('L5_HC', 0, 926, 5952599, [196, 20, 20, 20, 20, 20, 9, 6], 'region:480', 12, 5958937),
    ('L5_HC', 0, 1006, 5952679, [196, 20, 20, 20, 20, 20, 9, 6], 'region:489', 12, 5958949),
    ('L5_HC', 0, 5534, 5957207, [14, 14, 18, 18, 18, 18, 16, 14, 198], 'region:688', 12, 5959839),
    ('L5_HC', 1, 2162, 5894493, [9, 9, 9, 9, 9, 9, 9, 9, 9, 20, 16, 16], 'prop:238', 2, 5904333),
    ('L3_DH', 1, 12284, 5846666, [9, 197, 197, 197, 197, 197, 1, 20, 196, 198, 14], 'movable:65', 4, 5853644),
    ('L3_DH', 1, 12368, 5846750, [196, 198], 'movable:65', 2, 5853658),
    ('L3_DH', 1, 12392, 5846774, [9, 197, 197, 197, 197, 197], 'movable:65', 6, 5853672),
    ('L3_DH', 1, 2966, 5837348, [9, 16, 5, 7], 'prop:154', 4, 5849018),
    ('L3_DH', 1, 2996, 5837378, [7, 6, 16, 7, 5], 'prop:154', 6, 5849032),
    ('L3_DH', 1, 3032, 5837414, [24, 16], 'prop:154', 6, 5849042),
    ('L3_DH', 1, 3054, 5837436, [24], 'prop:154', 8, 5849052),
    ('L3_DH', 1, 3064, 5837446, [24], 'prop:154', 8, 5849058),
    ('L3_DH', 1, 3074, 5837456, [16], 'prop:154', 8, 5849064),
    ('L3_DH', 1, 3080, 5837462, [5, 7, 7, 16], 'prop:154', 6, 5849070),
    ('L3_DH', 1, 3110, 5837492, [9, 5, 6, 16, 7, 7], 'prop:154', 6, 5849080),
    ('L3_DH', 1, 6884, 5841266, [9, 9, 5, 2, 20, 198], 'control:78', 4, 5850964),
    ('L3_DH', 1, 6930, 5841312, [9, 20, 5, 198, 3], 'control:78', 4, 5850978),
    ('L3_DH', 0, 1558, 5883758, [1, 20], None, None, None),
]
# Further G95 statements checked on the records themselves.
G95_RECORDS = [
    # (area, owner, record file offset, field, expected)
    ('L7_DH', 'actor:73', 4883587, 'value', 10),          # "Actor 73 kind 6 value 10"
    ('L7_DH', 'region:83', 4950200, 'event', 2),          # "region 83, event 2, value 0"
    ('L7_DH', 'region:83', 4950200, 'value', 0),
    ('L7_DH', 'region:1338', 4950516, 'event', 4),        # "region 1338, event 4, value 0"
    ('L7_DH', 'region:1338', 4950516, 'value', 0),
    ('L5_HC', 'movable:81', 5907281, 'value', 1),         # "one kind-5 record with value 1"
    ('L5_HC', 'region:480', 5958937, 'event', 2),
    ('L5_HC', 'prop:238', 5904333, 'value', 48),          # "Prop 238 kind 2 value 48"
]
G95_DIR = Path('~/AI_COMMS/grok_backlog_20261028/G95_r12q_progression/mechanism')
# HOST_CONTRACT rows: (archive, file offset, command hex), copied from HOST_CONTRACT.md.
CONTRACT_COMMANDS = [
    ('L7_DH', 4874233, '012039006400'), ('L5_HC', 5902107, '012050005a00'), ('L7_DH', 4874161, '102039000300'),
    ('L7_DH', 4874227, '052039000300'), ('L7_DH', 4874217, '14203900100380000a14'), ('L7_DH', 4874211, 'c60000000201'),
    ('L7_DH', 4872847, '1010f7030100'), ('L7_DH', 4872837, '1410f703770280000a14'), ('L7_DH', 4861993, 'c60000000001'),
    ('L7_DH', 4862035, '1403db008a0180000a14'), ('L7_DH', 4862023, '0503e8000100'), ('L7_DH', 4861999, '012035006400'),
    ('L5_HC', 5952617, '14205200650132020a14'), ('L5_HC', 5957301, '1003ee000200'), ('L5_HC', 5957315, 'c60000001801'),
    ('L3_DH', 5846714, '14204100bd0280000a14'), ('L3_DH', 5846736, 'c60000001401'), ('L3_DH', 5837366, '05039a000100'),
    ('L3_DH', 5837360, '10039a000100'), ('L3_DH', 5846708, '012041006400'),
]
CONTRACT_REGION_RECORDS = [('L7_DH', 4950200, '080c4c0053000200'), ('L5_HC', 5958937, '080c9e03e0010200')]

# G97 evidence.json: predicate table entries (index, file offset, bytes), movable 57's trailers
# (owner record file offset, predicate index) and its event list.
G97_PREDICATES = [(206, 4989852, '0005000000'), (207, 4989857, '0005000001'), (208, 4989862, '0005000002'),
                  (2, 4988832, '0003020000')]
G97_DOOR57_TRAILERS = [(4883885, 206), (4883899, 207), (4883913, 208), (4883963, 2)]
G97_DOOR57_RECORDS = ['0a048635000000000000', '0413ce00', '0a049835000000000000', '0413cf00', '0a04aa35000000000000',
                      '0413d000', '0608c0357103', '0a09ce350e0104002884', '0a09da350e0104001e84',
                      '0a09e6350e0104001484', '0a0908360e0104000101', '04130200', '060518360000']

ACT_ONE = ('L1_DC', 'L3_DH', 'L4_HJ', 'L5_HC', 'L7_DH')


def load(root, area):
    return json.loads((root / OUT_DIR / f'{area}.json').read_text())


def check_g95(root, problems):
    data, checked = {}, 0
    for area in sorted({row[0] for row in G95_GROUPS}):
        data[area] = load(root, area)
    for area, stream, group, file_offset, opcodes, owner, kind, record_file in G95_GROUPS:
        d = data[area]
        g = next((g for g in d['groups'] if g['stream'] == stream and g['group'] == group), None)
        label = f'{area} stream {stream} group {group}'
        if g is None:
            problems.append(f'{label}: missing'); continue
        if g['file_offset'] != file_offset:
            problems.append(f'{label}: file {g["file_offset"]} != G95 {file_offset}')
        if [c['opcode'] for c in g['commands']] != opcodes:
            problems.append(f'{label}: opcodes {[c["opcode"] for c in g["commands"]]} != G95 {opcodes}')
        owners = [(o['ref'], e) for o in d['objects'] for e in o['events']
                  if e.get('stream') == stream and e.get('group') == group]
        if owner is None:
            if owners:
                problems.append(f'{label}: G95 says no owner, export has {[r for r, _ in owners]}')
        elif not any(ref == owner and e['kind'] == kind and e['file_offset'] == record_file for ref, e in owners):
            problems.append(f'{label}: no {owner} kind {kind} record at file {record_file}; export has '
                            f'{[(r, e["kind"], e["file_offset"]) for r, e in owners]}')
        checked += 1
    for area, owner, record_file, field, expected in G95_RECORDS:
        obj = next((o for o in data[area]['objects'] if o['ref'] == owner), None)
        event = next((e for e in (obj or {}).get('events', []) if e['file_offset'] == record_file), None)
        if event is None or event.get(field) != expected:
            problems.append(f'{area} {owner} record {record_file}: {field} {None if event is None else event.get(field)} != {expected}')
        checked += 1
    by_file = {area: {c['file_offset']: c['raw_hex'] for g in d['groups'] for c in g['commands']} for area, d in data.items()}
    for area, file_offset, hex_ in CONTRACT_COMMANDS:
        if by_file[area].get(file_offset) != hex_:
            problems.append(f'HOST_CONTRACT {area} {file_offset}: export {by_file[area].get(file_offset)} != {hex_}')
        checked += 1
    for area, file_offset, hex_ in CONTRACT_REGION_RECORDS:
        found = [e['raw_hex'] for o in data[area]['objects'] for e in o['events'] if e['file_offset'] == file_offset]
        if found != [hex_]:
            problems.append(f'HOST_CONTRACT {area} region record {file_offset}: export {found} != {hex_}')
        checked += 1
    # G97 step 1: the predicate table (header +0xBC offset, +0xB8 count, 5-byte entries).
    table = data['L7_DH']['predicate_table']
    for name, got, expected in [('count', table['count'], 255), ('file_offset', table['file_offset'], 4988822),
                                ('entries', len(table['entries']), 255)]:
        if got != expected:
            problems.append(f'G97 L7_DH predicate table {name} {got} != {expected}')
        checked += 1
    for index, file_offset, hex_ in G97_PREDICATES:
        if table['entries'][index] != hex_ or table['file_offset'] + 5 * index != file_offset:
            problems.append(f'G97 L7_DH predicate {index}: {table["entries"][index]} != {hex_} at {file_offset}')
        checked += 1
    door = next(o for o in data['L7_DH']['objects'] if o['ref'] == 'movable:57')
    trailers = [(e['file_offset'], e['predicate']['index']) for e in door['events'] if e.get('predicate')]
    if trailers != G97_DOOR57_TRAILERS:
        problems.append(f'G97 movable 57 trailers {trailers} != {G97_DOOR57_TRAILERS}')
    records = [e['raw_hex'] for e in door['events']]
    if records != G97_DOOR57_RECORDS:
        problems.append(f'G97 movable 57 records {records} != evidence.json')
    checked += 2
    # G97 step 2b: movable 57 placement byte +0x22 (mode) = 6, byte +0x24 = 60, angle word 21845 by the
    # 0x605F0 path (idiv 360 remainder of byte*2, shifted left 16, idiv 360).
    placement = bytes.fromhex(door['placement_hex'])
    word = ((placement[0x24] * 2 % 360) << 16) // 360
    if (len(placement), door['file_offset'], placement[0x22], placement[0x24], word) != (41, 4948198, 6, 60, 21845):
        problems.append(f'G97 2b movable 57 placement: size {len(placement)} file {door["file_offset"]} '
                        f'+0x22 {placement[0x22]} +0x24 {placement[0x24]} word {word}')
    checked += 1
    # Cross-check the vendored constants against Grok's own parsed data, when that read-only folder is present.
    mech = G95_DIR / 'mechanism.json'
    if mech.is_file():
        grok = json.loads(mech.read_text())
        for name, category in grok['categories'].items():
            for c in category.get('commands', []):
                area = c['archive'].replace('.MIX', '')
                if area in by_file and by_file[area].get(c['offset']) != c['hex']:
                    problems.append(f'mechanism.json {name} {area} {c["offset"]}: export {by_file[area].get(c["offset"])} != {c["hex"]}')
                checked += 1
    return checked


def check_determinism(root, game, problems):
    sys.path.insert(0, str(ROOT / 'tools'))
    import prepare_native_scripts as producer
    profiles = json.loads((ROOT / 'docs/game-geometry-profiles.json').read_text())
    areas = [a['id'] for a in profiles['areas']]
    runs = []
    with tempfile.TemporaryDirectory() as temporary:
        for name in ('a', 'b'):
            out = Path(temporary) / name
            if producer.main(['--game', str(game), '--all', '--output-root', str(out)]) != 0:
                problems.append(f'producer run {name} did not pass')
            runs.append({p.relative_to(out).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in sorted(out.rglob('*.json'))})
    if runs[0] != runs[1]:
        problems.append('two producer runs differ')
    for rel, digest in runs[0].items():
        staged = root / rel
        if staged.is_file() and hashlib.sha256(staged.read_bytes()).hexdigest() != digest:
            problems.append(f'staged {rel} differs from a fresh run')
    return len(areas)


## Static mirror of scripts/lol2/native_script_host.gd (keep in step with its handlers and matchers).
## Each command, matcher path and predicate is 'P' (PROVEN), 'A' (runs only on an adapter) or a reason.
CLASS_BY_KIND = {0x10: 'control', 0x20: 'movable', 0x03: 'prop', 0x02: 'actor', 0x04: 'kind4'}
TABLE_BY_KIND = {0x10: 'control', 0x20: 'movable', 0x03: 'prop', 0x02: 'actor'}
OBJECT_KINDS = {0x01, 0x02, 0x03, 0x04, 0x10, 0x20, 0x80, 0x90, 0xA0, 0xB0, 0xC0}
FOUR = ('movable', 'control', 'prop', 'actor')


def classify_command(c, area):
    b = bytes.fromhex(c['raw_hex'])
    op, kind = b[0], b[1]
    cls = CLASS_BY_KIND.get(kind, '')
    if op in (20, 198):
        return 'P'
    if op == 204:
        return 'op 204 -1 arm' if int.from_bytes(b[4:6], 'little', signed=True) == -1 else 'P'
    if op == 2:
        # 0x1C PROVEN; backlog 4 item 0: 0x26/0x27/0x0B/0x0C/57 on the 0x22574 object and arm 5 (needs an object) on adapters.
        if b[4] == 0x1C:
            return 'P'
        if b[4] == 0x24:
            return 'P'  # backlog 5 item 9: bits 0x10/0x20 of the 0x22574 object's +0x228, PROVEN body
        if b[4] == 0x18:
            return 'A'  # backlog 6 item 1c: adapter opcode2_arm18_clear
        if b[4] == 0x3C:
            return 'A'  # backlog 6 item 1d: PROVEN return 1, the stores on adapter opcode2_arm3c
        if b[4] in (0x26, 0x27, 0x0B, 0x0C, 57):
            return 'A'
        if b[4] in (5, 6):
            return 'A' if kind in OBJECT_KINDS else f'op 2 arm {b[4]} kind 0x{kind:02x} selects no object'
        return f'op 2 arm {b[4]}'
    if op == 197:
        # 0x64CD4 reads only the command: arms 0-5/8/9 are PROVEN bit stores on the [0x22D0C] record, arms above 10 store
        # nothing; arms 6/7 (unloaded word +0x18) and 10 (unheld [0x2B53C] table) run on adapters.
        return 'P' if b[4] > 10 or b[4] in (0, 1, 2, 3, 4, 5, 8, 9) else 'A'
    if op == 12:
        return 'P' if b[4] >= 46 else 'A'  # backlog 6 item 1c: adapter opcode12_room (room stem table, 46 slots)
    if op == 210:
        return 'P' if b[4] > 0x0B else ('A' if b[4] == 9 else f'op 210 arm {b[4]}')  # adapter opcode210_arm9
    if op == 3 and kind == 1:
        return 'A'  # backlog 6 item 1c: adapter opcode3_item_grant (give item)
    if op == 18:
        # backlog 4 item 4: no byte-4 read; bit 5 of the word +0xA (clear in Act 1) would run 0x660F8 (adapter opcode18_pending_slot).
        return 'A' if (b[10] & 0x20) == 0 else 'op 18 bit 5 of byte 0xA'
    if op == 208:
        return 'A' if b[4] == 0 else f'op 208 arm {b[4]}'
    if kind not in OBJECT_KINDS:
        return f'op {op} kind 0x{kind:02x} selects no object'
    if op == 15:
        return 'P' if b[4] > 0x70 else 'A'  # above 0x70: the epilogue (no store); forms: adapter opcode15_effect_request
    if op == 19:
        return f'op 19 byte 9 {b[9]} (vtable percentage)' if b[9] in (1, 2) else 'A'  # adapter opcode19_effect_record
    if op == 16:
        return 'P'
    if op in (1, 3, 13):
        if cls == 'movable':
            if op != 1:
                return 'P'
            bound = area['placements'].get(f'movable:{c["target"]}')
            if bound is None:
                return 'op 1 movable unbound'
            return 'A'  # mode 6 (slot_index_binding) or another mode (opcode1_other_modes, backlog 5 item 9)
        if cls in ('control', 'prop'):
            return 'P'
        if cls == 'actor' and op == 1:
            return 'P'
        if cls == 'actor' and op == 13:
            # backlog 4 item 0: slots 6/10 and byte 4 > 0x16 are PROVEN stores behind the +0xA8 gate (adapter opcode13_actor_a8).
            return 'A' if (b[4] in (6, 7, 10, 0x0D) or b[4] > 0x16) else f'op 13 actor slot {b[4]}'
        return f'op {op} slot +0xAC {cls or hex(kind)}'
    if op == 5:
        if cls in ('movable', 'control'):
            return 'A'
        if cls == 'kind4':
            return 'P'
        if cls in ('prop', 'actor') and b[5] == 0:
            return 'A'
        return f'op 5 {cls or hex(kind)}'
    if op == 7:
        if cls == 'prop' and b[4] in (0, 1, 7, 8):
            return 'P'
        if cls == 'actor' and not 2 <= b[4] <= 6:
            return 'P'
        if cls == 'control':
            # backlog 4 item 9: indexes 0/7 OR bits into the control's records (adapter opcode7_control_records); above 9 no store.
            return 'A' if b[4] in (0, 7) else ('P' if b[4] > 9 else f'op 7 control index {b[4]}')
        return f'op 7 {cls or hex(kind)} index {b[4]}'
    if op == 9:
        arm = b[4]
        if arm in (0, 1, 7, 8, 9, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x11, 0x12, 0x13):
            return 'P'
        if arm in (2, 3, 0x15):
            return 'A'
        if 0x1A <= arm <= 0x1D:
            return 'P' if cls in FOUR else f'op 9 arm {arm:#x} {hex(kind)}'
        if arm > 0x22:
            if cls in ('movable', 'control', 'prop') or (cls == 'actor' and arm != 0x25):
                return 'P'
            return f'op 9 arm {arm:#x} {cls or hex(kind)}'
        return f'op 9 arm {arm:#x}'
    if op == 14:
        if cls not in FOUR:
            return f'op 14 {hex(kind)}'
        if b[4] > 6:
            return 'P'
        if b[4] > 4:
            return f'op 14 arm {b[4]}'
        lst = area['lists'].get(f'{TABLE_BY_KIND[kind]}:{c["target"]}')
        if not lst or not any(len(r) >= 2 and r[1] == 2 for r in lst):
            return 'op 14 no kind-2 record'
        return 'A'
    if op == 6:
        return 'A' if b[4] <= 6 else ('P' if b[4] > 0x0C else f'op 6 arm {b[4]}')
    if op == 8:
        return 'A' if b[4] <= 10 and b[4] != 9 else f'op 8 arm {b[4]}'
    if op == 21:
        index = int.from_bytes(b[4:5], 'little', signed=True)
        return 'A' if 0 <= index <= 85 else 'P'  # outside the table: 0xCF2B4 leaves the index path (no-op)
    return f'op {op} no handler'


def matcher_path(owner, e):
    """'P', 'A' or a reason, for the record's own matcher (inputs supplied by the caller)."""
    b = bytes.fromhex(e['raw_hex'])
    kind = e['kind']
    if 'region' in e:
        return 'P' if e['event'] == 2 else f'region event slot {e["event"]}'
    if kind in (5, 6, 8):
        return 'P'
    if kind == 4:
        if b[4] == 3:
            return 'P'  # backlog 6 item 1d: mode 3 compares the argument object's +0x18 with the record dword +6 (input supplied)
        if b[4] != 0 or b[5] != 0:
            return 'kind 4 mode/inversion'
        # movable/control: 0xB5000 tests +0x15 bit 0x80 first (not known at load).
        return 'A' if owner.split(':')[0] in ('movable', 'control') else 'P'
    if kind == 9:
        mode = b[9] & 7
        if mode == 4:
            return 'P'
        if mode == 1:
            return 'P' if b[8] <= 0x7F else 'kind 9 mode 1 byte +8 extension'
        return f'kind 9 mode {mode}'
    if kind == 2:
        return 'A'  # timers: adapter kind2_timer_expiry (backlog 5 item 9)
    return f'kind {kind} matcher not entered'


def predicate_path(owner, e, entries):
    p = e.get('predicate')
    if not p:
        return 'P'
    if p['index'] >= len(entries):
        return 'predicate outside table'
    entry = bytes.fromhex(entries[p['index']])
    if entry[0] not in (0, 5, 6):
        return f'operator {entry[0]}'
    if entry[3] != 0:
        return f'right type {entry[3]}'
    if entry[1] == 2:
        return 'left type 2 (0x26E58 array, nothing PROVEN writes it)'
    if entry[1] == 5:
        # Kind-4 default context: the object itself when +0x15 bit 0x10 is clear (not known at load).
        return 'A' if e['kind'] == 4 and owner.split(':')[0] in ('movable', 'control') else 'P'
    if entry[1] == 3:
        return 'P'
    return f'left type {entry[1]}'


def link_status(owner, e, g, area):
    """('P'|'A'|None, reason). P: runs on PROVEN paths only; A: needs at least one adapter."""
    worst = 'P'
    for step in [classify_command(c, area) for c in g['commands']] + [matcher_path(owner, e),
                                                                       predicate_path(owner, e, area['entries'])]:
        if step == 'A':
            worst = 'A'
        elif step != 'P':
            return None, step
    return worst, ''


def area_index(d):
    placements, lists = {}, {}
    for o in d['objects']:
        if 'placement_hex' in o:
            placements[o['ref']] = bytes.fromhex(o['placement_hex'])
        lists[o['ref']] = [bytes.fromhex(e['raw_hex']) for e in o['events']]
    return dict(placements=placements, lists=lists, entries=d['predicate_table']['entries'])


def coverage(root):
    print('\nCoverage of event-owned groups (static mirror of native_script_host.gd):')
    print('  PROVEN : every command, the matcher path and the predicate run on PROVEN paths (caller inputs given)')
    print('  +ADAPT : the same, allowing the named adapters (ADAPTERS in native_script_host.gd)')
    totals, blocked = Counter(), Counter()
    for path in sorted((root / OUT_DIR).glob('*.json'), key=lambda p: int(p.stem.split('_')[0][1:])):
        d = json.loads(path.read_text())
        area = area_index(d)
        groups = {(g['stream'], g['group']): g for g in d['groups']}
        tiers = Counter()
        for o in d['objects']:
            for e in o['events']:
                if 'group' not in e:
                    continue
                status, reason = link_status(o['ref'], e, groups[(e['stream'], e['group'])], area)
                tiers['links'] += 1
                if status == 'P':
                    tiers['P'] += 1
                if status in ('P', 'A'):
                    tiers['A'] += 1
                elif d['area'] in ACT_ONE:
                    blocked[reason.split(' at ')[0]] += 1
        n = tiers['links'] or 1
        print(f'  {d["area"]:7} links {tiers["links"]:5}  PROVEN {tiers["P"]:4} ({100*tiers["P"]/n:4.1f}%)  '
              f'+ADAPT {tiers["A"]:4} ({100*tiers["A"]/n:4.1f}%)')
        if d['area'] in ACT_ONE:
            for k, v in tiers.items():
                totals[k] += v
    n = totals['links'] or 1
    print(f'  Act 1 ({", ".join(ACT_ONE)}): links {totals["links"]}, PROVEN {totals["P"]} ({100*totals["P"]/n:.1f}%), '
          f'+ADAPT {totals["A"]} ({100*totals["A"]/n:.1f}%)')
    print('  Act 1 links still blocked, top reasons: ' + ', '.join(f'{k} {v}' for k, v in blocked.most_common(14)))
    print('\nG95 door, slot and chain records (REPORT.md included groups, owner records):')
    data, counts = {}, Counter()
    for area_id, stream, group, _file, _ops, owner, _kind, record_file in G95_GROUPS:
        if owner is None or area_id != 'L7_DH' and owner != 'movable:80':
            continue
        if area_id not in data:
            dd = json.loads((root / OUT_DIR / f'{area_id}.json').read_text())
            data[area_id] = (dd, area_index(dd))
        dd, area = data[area_id]
        g = next(x for x in dd['groups'] if x['stream'] == stream and x['group'] == group)
        e = next(x for o in dd['objects'] if o['ref'] == owner for x in o['events'] if x['file_offset'] == record_file)
        status, reason = link_status(owner, e, g, area)
        counts[status or 'blocked'] += 1
        label = {'P': 'runs (PROVEN)', 'A': 'runs on adapters', None: 'blocked: ' + reason}[status]
        print(f'  {area_id} {owner:13} kind {e["kind"]:2} group {group:5} opcodes {[c["opcode"] for c in g["commands"]]}: {label}')
    print(f'  {counts["P"]} PROVEN, {counts["A"]} on adapters, {counts["blocked"]} blocked, of {sum(counts.values())}.')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--scripts-root', type=Path, default=ROOT, help='root holding scripts/lol2/native_scripts')
    parser.add_argument('--game', type=Path, help='also run the producer twice and compare bytes')
    parser.add_argument('--coverage', action='store_true')
    args = parser.parse_args()
    problems = []
    checked = check_g95(args.scripts_root, problems)
    print(f'G95 rows checked: {checked}')
    if args.game:
        print(f'determinism: {check_determinism(args.scripts_root, args.game, problems)} areas, two runs')
    if args.coverage:
        coverage(args.scripts_root)
    for problem in problems:
        print('MISMATCH', problem)
    if problems:
        return 1
    print('PASS native scripts match G95 REPORT.md and HOST_CONTRACT.md' + (' and are byte-identical across runs' if args.game else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
