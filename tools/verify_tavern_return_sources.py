#!/usr/bin/env python3
"""Source evidence for the tavern return / Huline alert slice (docs/tavern-return.md).

L4_HJ (Huline Jungle):
- Geometry local-name table (+0xB0 count, +0xB4 initials, 41-byte names): local36 == "Left_Village".
- Op 0xC6 = set level local (anchor: alarm g27172 writes local52=1, local7=2, local8=30, local32=1 as documented).
- The only L4_HJ writers of local36: region3501 event2 g7092 predicate164 (local36==0) -> 2;
  region3805 event2 g7950 predicate165 (local36==2) -> 3.
CAN room DLL (CAN.MIX / WOMS\\CAN_.WOM):
- Host import slots are a shared table; T = highest used slot - 0x13C. Its meanings are cross-checked on MOFF/MLIB/CAN
  (movie +0x50, set_flag +0x44, clear_flag +0x48, test_flag +0x4C, get_global +0x70, set_global +0x9C,
  set_local +0xB4, get_local +0xB8, room +0x88, close +0x68, give_item +0x3C, movie_flags +0x11C).
- Setup 0x9EA..0xC21, when flag34 is set:
  - Left_Village == 3: maid lines (speaker32) 700..707 (with movie_flags variants), debug print, GV_HULINE_ALERT = 1,
    line 708, host +0xE4(1) if flag267 is clear, line 709, set flag267, room VILLAGE, close.
  - else flag42 clear: set 42, lines 662/663 (13), 664/665 (1), 666 (13).
  - else flag43 clear: set 43, line 675 (13).
  - else flag44 clear: clear 37, set 44, call 0xE09 (the first-visit farewell: set34, relationship 0, clear37, 637/638/676/677).
- Media: the 16 clips exist in CAN.MIX; size and sha256 are recorded.
Writes docs/tavern-return-checks.json and scripts/lol2/tavern_return_source.json (numbers and names only).
"""
import hashlib, json, re, struct
from pathlib import Path
import capstone
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate
from audit_monastery_rooms import GAME, extract

ROOT = Path(__file__).resolve().parents[1]
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
CAN_ARCHIVE = '55395c6cfa2f846f4edb360877ab9c68002dce1367a5109624e1c3feba634675'
CAN_DLL = '60835dcd4a697b208ac264faa72eb7e9b71eac35178d08a91fb7f54a414d6e92'
SLOTS = {0x3c: 'give_item', 0x44: 'set_flag', 0x48: 'clear_flag', 0x4c: 'test_flag', 0x50: 'movie', 0x68: 'close', 0x70: 'get_global',
         0x88: 'room', 0x9c: 'set_global', 0xb4: 'set_local', 0xb8: 'get_local', 0x11c: 'movie_flags', 0x0: 'debug_print', 0xe4: 'unknown_e4'}
SEQUENCES = {'CAN_MAID': [[32, n] for n in range(700, 710)], 'CAN_REVISIT': [[13, 662], [13, 663], [1, 664], [1, 665], [13, 666]],
             'CAN_REVISIT_LATE': [[13, 675]]}


def module(mix, wom):
    archive = (GAME / 'DAT' / mix).read_bytes()
    dll, entry = extract(archive, wom)
    _, size, _, _ = struct.unpack_from('<4I', dll, 32)
    return archive, dll, entry, dll[48:48 + size]


def table_base(m):
    used = sorted({struct.unpack('<I', x.group(1))[0] for x in re.finditer(rb'\xff\x15(....)', m)})
    used = [s for s in used if s < len(m)]
    return max(used) - 0x13c


def string_at(m, offset):
    return m[offset:].split(b'\0')[0].decode()


def trace(m, base, start, end):
    """Calls in [start, end) with their pushed arguments (immediates resolved to strings where they point at one)."""
    rows, pushes = [], []
    for i in md.disasm(m[start:end], start):
        if i.mnemonic == 'push':
            pushes.append(i.op_str)
        elif i.mnemonic == 'call':
            mm = re.match(r'dword ptr \[(0x[0-9a-f]+)\]$', i.op_str)
            if mm:
                kind = SLOTS.get(int(mm.group(1), 16) - base, hex(int(mm.group(1), 16) - base))
                args = []
                for p in reversed(pushes):
                    if p.startswith('0x') and int(p, 16) < len(m) and int(p, 16) >= 0xe9c and m[int(p, 16)] >= 0x20:
                        args.append(string_at(m, int(p, 16)))
                    else:
                        args.append(int(p, 16) if p.startswith('0x') else (int(p) if p.lstrip('-').isdigit() else p))
                rows.append(dict(address=hex(i.address), kind=kind, args=args))
            else:
                rows.append(dict(address=hex(i.address), kind='near', target=i.op_str))
            pushes = []
        elif i.mnemonic in ('add',) and i.op_str.startswith('esp'):
            pass
        elif i.mnemonic in ('jmp', 'ret', 'je', 'jne'):
            rows.append(dict(address=hex(i.address), kind=i.mnemonic, target=i.op_str)); pushes = []
    return rows


def main():
    report = {}
    # ---- L4_HJ local36 writers ----
    area, arc, entry, raw, owners, streams = source_area('L4_HJ')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    count, at = struct.unpack_from('<I', raw, 0xb0)[0], struct.unpack_from('<I', raw, 0xb4)[0]
    name36 = raw[at + count + 36 * 41:at + count + 36 * 41 + 41].split(b'\0')[0].decode()
    assert name36 == 'Left_Village', name36
    g27172 = [c['raw_hex'] for c in streams[1][27172]]
    for want in ('c60000003401', 'c60000000702', 'c6000000081e', 'c60000002001'): assert want in g27172
    writers = []
    for si, st in enumerate(streams):
        for g, cmds in st.items():
            for c in cmds:
                b = bytes.fromhex(c['raw_hex'])
                if b[0] == 0xc6 and len(b) == 6 and b[4] == 36: writers.append((si, g, c['raw_hex']))
    assert sorted(writers) == [(0, 7092, 'c60000002402'), (0, 7950, 'c60000002403')], writers
    regions = {}
    for region, group, pred, raw_pred, value in [(3501, 7092, 164, '0003240000', 2), (3805, 7950, 165, '0003240002', 3)]:
        o = [x for x in owners if x['stream'] == 0 and x['group'] == group]
        assert len(o) == 1 and o[0]['owner_kind'] == 'region' and o[0]['owner'] == region and o[0]['event'] == 2 and o[0]['predicate'] == pred
        assert predicate(table, pred)['raw'] == raw_pred
        regions[str(region)] = dict(group=group, event=2, predicate=pred, predicate_raw=raw_pred, requires=value - (2 if value == 2 else 1), sets=value,
                                    archive_offset=o[0]['archive_offset'])
    regions['3501']['requires'] = 0; regions['3805']['requires'] = 2
    report['l4_hj'] = dict(source=area['source'], local36=name36, op_c6_anchor='g27172 local52/7/8/32 writes', writers=[list(w) for w in writers], regions=regions)
    # ---- Import table anchors ----
    anchors = {}
    for mix, wom, checks in [
            ('MOFF.MIX', 'WOMS\\MOFF_.WOM', [(0x141c, 'give_item'), (0x1430, 'movie'), (0x1424, 'set_flag'), (0x14fc, 'movie_flags')]),
            ('MLIB.MIX', 'WOMS\\MLIB_.WOM', []),
            ('CAN.MIX', 'WOMS\\CAN_.WOM', [(0xf8c, 'movie'), (0xf80, 'set_flag')])]:
        _, _, _, m = module(mix, wom); base = table_base(m)
        for slot, kind in checks: assert SLOTS[slot - base] == kind, (mix, hex(slot), kind)
        anchors[mix] = dict(base=hex(base), checked=[[hex(s), k] for s, k in checks])
    # Semantic anchors already hosted by the port: MLIB get_local "Dawn_dam_out_cave", set_local "Met_Dawn" 1, set_global "GV_RUNES_TRANSLATED" 1.
    _, _, _, mlib = module('MLIB.MIX', 'WOMS\\MLIB_.WOM'); b = table_base(mlib)
    t = trace(mlib, b, 0x47c, len(mlib) - 0x200)
    def has(kind, args): return any(r['kind'] == kind and r.get('args') == args for r in t)
    assert has('get_local', ['Dawn_dam_out_cave']) and has('set_local', ['Met_Dawn', 1]) and has('set_global', ['GV_RUNES_TRANSLATED', 1])
    anchors['MLIB.MIX']['semantic'] = ['get_local Dawn_dam_out_cave', 'set_local Met_Dawn 1', 'set_global GV_RUNES_TRANSLATED 1']
    report['import_anchors'] = anchors
    # ---- CAN later-visit setup ----
    archive, dll, entry, m = module('CAN.MIX', 'WOMS\\CAN_.WOM')
    assert hashlib.sha256(archive).hexdigest() == CAN_ARCHIVE and entry['sha256'] == CAN_DLL
    base = table_base(m); assert base == 0xf3c
    setup = trace(m, base, 0x9ea, 0xc21)
    calls = [(r['kind'], r.get('args')) for r in setup if r['kind'] not in ('near', 'jmp', 'je', 'jne', 'ret')]
    maid = [x for x in calls if x[0] in ('movie', 'movie_flags')]
    # Maid branch: movies 700..709 speaker32; GV_HULINE_ALERT=1; flag267.
    # 0x9EA first starts the room's ambient sound (+0x138: 398, 150; not a gameplay effect), then the later-visit test.
    want = [('0x138', [398, 150]), ('test_flag', [34]), ('get_local', ['Left_Village'])]
    assert calls[:len(want)] == want, calls[:4]
    lines = [(a[0], a[1]) for k, a in calls if k in ('movie', 'movie_flags')]
    assert lines[:10] == [(32, n) for n in range(700, 710)], lines[:10]
    assert ('debug_print', ['&&& CAN_.C: Maid smiles, blue light happens\r']) in calls and ('set_global', ['GV_HULINE_ALERT', 1]) in calls
    i_alert = calls.index(('set_global', ['GV_HULINE_ALERT', 1])); i_707 = [i for i, c in enumerate(calls) if c[0].startswith('movie') and c[1][1] == 707][0]
    i_708 = [i for i, c in enumerate(calls) if c[0].startswith('movie') and c[1][1] == 708][0]
    i_709 = [i for i, c in enumerate(calls) if c[0].startswith('movie') and c[1][1] == 709][0]
    assert i_707 < i_alert < i_708 < i_709 and calls[i_709 + 1] == ('set_flag', [267]) and calls[i_709 + 2] == ('room', ['VILLAGE_']) and calls[i_709 + 3] == ('close', [])
    assert ('unknown_e4', [1]) in calls[i_708:i_709] and ('test_flag', [267]) in calls[i_708:i_709]
    flagged = {c[1][1]: c[1][3] for c in calls if c[0] == 'movie_flags'}
    # Revisit: flag42 -> 662..666; flag43 -> 675; flag44 -> clear37, set44, near call 0xE09.
    rest = calls[i_709 + 4:]
    assert rest[:2] == [('test_flag', [42]), ('set_flag', [42])], rest[:3]
    assert [(a[0], a[1]) for k, a in rest if k == 'movie'][:5] == [(13, 662), (13, 663), (1, 664), (1, 665), (13, 666)]
    # Line 675 (flag43 branch) shares the 666 call site: push 6, push 0x2A3, jmp 0xBC1 -> push 0xD; call movie.
    text = {i.address: f'{i.mnemonic} {i.op_str}' for i in md.disasm(m[0xbe1:0xbf5], 0xbe1)}
    text.update({i.address: f'{i.mnemonic} {i.op_str}' for i in md.disasm(m[0xbc1:0xbcc], 0xbc1)})
    assert [text[a] for a in (0xbec, 0xbee, 0xbf3, 0xbc1, 0xbc3)] == ['push 6', 'push 0x2a3', 'jmp 0xbc1', 'push 0xd', 'call dword ptr [0xf8c]'], text
    assert ('test_flag', [43]) in rest and ('set_flag', [43]) in rest and ('test_flag', [44]) in rest and ('clear_flag', [37]) in rest and ('set_flag', [44]) in rest
    nears = [r['target'] for r in setup if r['kind'] == 'near']
    assert '0xe09' in nears
    exit_calls = [(r['kind'], r.get('args')) for r in trace(m, base, 0xe09, 0xe9c) if r['kind'] not in ('near', 'jmp', 'je', 'jne', 'ret')]
    assert ('set_flag', [34]) in exit_calls and ('set_global', ['GV_BACATTA_RELATIONSHIP', 0]) in exit_calls and ('clear_flag', [37]) in exit_calls
    spans = {k: hashlib.sha256(m[a:z]).hexdigest() for k, (a, z) in {'setup_later_0x9ea': (0x9ea, 0xc21), 'exit_0xe09': (0xe09, 0xe9c)}.items()}
    report['can'] = dict(archive_sha256=CAN_ARCHIVE, dll_sha256=CAN_DLL, table_base=hex(base), spans=spans, setup_calls=calls, exit_calls=exit_calls,
                         movie_flags=flagged, unknown=['host +0xE4(1) before line709 when flag267 is clear', 'movie_flags variants 0x80/0xA0/0xE0',
                                                       'debug print +0x0'])
    # ---- Media ----
    media = {}
    for seq, clips in SEQUENCES.items():
        rows = []
        for speaker, number in clips:
            ext = 'AUD' if speaker == 1 else 'VQA'
            name = f'WOMS\\CAN\\{speaker:02d}{number:03d}06E.{ext}'
            payload, rec = extract(archive, name)
            rows.append(dict(speaker=speaker, line=number, name=name, size=len(payload), sha256=hashlib.sha256(payload).hexdigest(),
                             kind='audio_only' if speaker == 1 else 'movie', movie_flags=flagged.get(number)))
        media[seq] = rows
    report['media'] = media
    source = dict(version=1, left_village=dict(local='Left_Village', l4_hj_local=36, regions=regions),
                  sequences={k: [dict(speaker=r['speaker'], line=r['line'], name=r['name'], sha256=r['sha256'], kind=r['kind']) for r in v] for k, v in media.items()},
                  effects=dict(CAN_MAID={'after_line_707': ['GV_HULINE_ALERT=1'], 'after_line_708': ['unknown_e4(1) if flag267 clear (not hosted)'],
                                         'after_line_709': ['flag267=1', 'room VILLAGE']},
                               CAN_REVISIT={'start': ['flag42=1']}, CAN_REVISIT_LATE={'start': ['flag43=1']},
                               farewell={'start': ['flag37=0', 'flag44=1'], 'then': 'existing CAN_EXIT (0xE09)'}))
    (ROOT / 'scripts/lol2/tavern_return_source.json').write_text(json.dumps(source, indent=1) + '\n')
    report['passed'] = True
    (ROOT / 'docs/tavern-return-checks.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS tavern return sources: L4_HJ local36 Left_Village writers g7092/g7950 (only two), import anchors MOFF/MLIB/CAN, '
          'CAN later-visit setup (maid 700-709 + alert + flag267; revisit 662-666/675; farewell 0xE09), %d media clips' % sum(len(v) for v in media.values()))


if __name__ == '__main__':
    main()
