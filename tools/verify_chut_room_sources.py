#!/usr/bin/env python3
"""Source evidence for the chief's-hut room CHUT entered from Kelsrick's gate line (docs/jungle-chut-room.md).

L4_HJ: region2750 event2 group5084 (predicate20 local6 == 0) ends with op12 control100 -> room14 (0c1064000e00) and
op9 control100 property21 (091064001500), the same op12+op9/21 pair that opens VILLAGE (Bacatta57) and RUNES (Hive
pit). LOLG.DAT room names, in table order, give index 14 = "chut_" (anchors: 3 ment_, 10 runecl_, 11 runes_, 12 village_).

CHUT.MIX / WOMS\\CHUT_.WOM, static disassembly only (no DLL execution). Host slots are bound by the DLL initializer
(`mov edx,[eax+off]; mov [slot],edx`); names follow the host-table offsets already proven for the other room DLLs
(verify_liz_room_sources.HOSTS, verify_tavern_return_sources.SLOTS, CAN idle/actor calls). Offset 0xE0 is the call
MCEL hotspot1 uses for the cellar passage placement (tools/prepare_dark_halls_routes.py CELLAR): place(x, y).
- Setup 0x47C: load_room("hut-apr",1,1) unconditionally; background "chut"; unless flag150: speaker29 actor hotspot
  and idle(29, 999 or 995 when GV_KELSRICK_DEAD, 6).
- Callback9 0x890 (first update): ambient_start(338,170); flag153 -> done. Kelsrick alive, flags152/150 clear and
  Kelsrick_Attacked clear (0x9C4): set flag152, lines 29/350..364 (view 6; movie_flags 0x80/0xA0 variants are
  temporary host flags, unbound as in the monastery rooms), set flag151 after line 358, set_local Met_Kelsrick = 1
  after line 362, then place(-1769, 5464), host 0xF0(150), exit_room.
- Callback8 0x866 (leave): place(-1769, 5464), host 0xF0(150), exit_room.
- Kelsrick-dead branch0x8C4: flag153/150 clear, dead global nonzero; raise alert, set153, lines375..379, remain in room.
- Not hosted: Kelsrick_Attacked/Anyar attack branch (0x6E8), flag150 stone hotspots
  (0x594), message5 lines 366/367 (0x68B). Host 0xF0's argument is 150 here; all 23 0xF0 calls in the room DLLs use
  0..359, so it is read as a facing in degrees, 0 = east, counterclockwise (longplay f_00756: Luther faces Kelsrick);
  an interpretation, not a traced host routine.
Writes scripts/lol2/chut_room_source.json (numbers and names only).
"""
import hashlib, json, re, struct
from pathlib import Path
import capstone
from audit_monastery_rooms import GAME, extract, movie
from verify_actor_item_grants import source_area

ROOT = Path(__file__).resolve().parents[1]
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
CHUT_MIX = 'd623157008700d95e3e09cd7462c7d7032a06bfdff48b15ece11fc7c79dc4be7'
CHUT_DLL = 'edf0996f0fb100e244a5a6188fb8121ad241a47bdcacab360686837aed0d11b6'
EXE = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
HOSTS = {0x10: 'hotspot', 0x20: 'actor', 0x24: 'actor_state', 0x28: 'idle', 0x40: 'give_item', 0x48: 'set_flag', 0x50: 'get_flag',
         0x54: 'movie', 0x68: 'exit_room', 0x70: 'get_global', 0x9c: 'set_global', 0xb4: 'set_local', 0xb8: 'get_local',
         0xbc: 'load_room', 0xe0: 'place', 0xf0: 'host_f0', 0x11c: 'movie_flags', 0x138: 'ambient_start', 0x13c: 'ambient_stop'}
LINES = list(range(350, 365))


def digest(b):
    return hashlib.sha256(b).hexdigest()


def slots(module):
    rows = list(md.disasm(module[0xf6:0x47c], 0xf6)); out = {}
    for k in range(1, len(rows)):
        store = re.match(r'dword ptr \[(0x[0-9a-f]+)\], (edx|eax)$', rows[k].op_str)
        load = re.match(r'(edx|eax), dword ptr \[eax(?: \+ (0x[0-9a-f]+|[0-9]+))?\]$', rows[k - 1].op_str)
        if rows[k].mnemonic == 'mov' and store and load and store.group(2) == load.group(1):
            out[int(store.group(1), 16)] = int(load.group(2) or '0', 0)
    return out


def calls(module, table, start, end):
    """Host calls in [start, end) with literal arguments (call order); strings resolved from the data block."""
    rows, pushes = [], []
    for i in md.disasm(module[start:end], start):
        if i.mnemonic == 'push':
            pushes.append(i.op_str)
        elif i.mnemonic == 'call':
            m = re.match(r'dword ptr \[(0x[0-9a-f]+)\]$', i.op_str)
            if m:
                args = []
                for p in reversed(pushes):
                    if p.startswith('0x') and 0xbb0 <= int(p, 16) < 0xc30:
                        args.append(module[int(p, 16):].split(b'\0')[0].decode())
                    elif p.startswith('0x'):
                        v = int(p, 16); args.append(v - (1 << 32) if v >= 1 << 31 else v)
                    else:
                        args.append(int(p) if p.lstrip('-').isdigit() else p)
                offset = table[int(m.group(1), 16)]
                rows.append(dict(address=hex(i.address), host=HOSTS.get(offset, hex(offset)), offset=hex(offset), args=args))
            pushes = []
        elif i.mnemonic in ('jmp', 'ret'):
            pushes = []
    return rows


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes(); assert digest(exe) == EXE
    at = exe.find(b'pool_\0cave_\0'); assert at > 0
    names = exe[at:at + 400].split(b'\0')
    names = [n.decode() for n in names[:names.index(b'balcony_') + 1]]
    assert (names[3], names[10], names[11], names[12], names[14]) == ('ment_', 'runecl_', 'runes_', 'village_', 'chut_'), names
    archive = (GAME / 'DAT/CHUT.MIX').read_bytes(); assert digest(archive) == CHUT_MIX
    dll, record = extract(archive, 'WOMS\\CHUT_.WOM'); assert record['sha256'] == CHUT_DLL
    version, size, entry, count = struct.unpack_from('<4I', dll, 32)
    assert dll[:32] == b'This is a linear executable dll\n' and version == 257 and entry == 52 and len(dll) == 48 + size + count * 4
    module = dll[48:48 + size]
    table = slots(module)
    assert table[0xc84] == 0x54 and table[0xc78] == 0x48 and table[0xc80] == 0x50 and table[0xd14] == 0xe0 and table[0xd24] == 0xf0
    for offset, text in [(0xbb4, 'hut-apr'), (0xbbc, 'chut'), (0xbc1, 'GV_KELSRICK_DEAD'), (0xc11, 'Kelsrick_Attacked'), (0xc23, 'Met_Kelsrick')]:
        assert module[offset:].split(b'\0')[0].decode() == text, text
    setup = calls(module, table, 0x47c, 0x567)
    assert [r['host'] for r in setup[:2]] == ['load_room', '0x8'] and setup[0]['args'] == ['hut-apr', 1, 1] and setup[1]['args'] == ['chut']
    idle = [r for r in setup if r['host'] == 'idle']
    assert len(idle) == 1 and idle[0]['args'] == [29, 999, 6]  # 0x54F alive path; the dead path (0x546) pushes 995 and jumps to the same call
    first = calls(module, table, 0x9c4, 0xb9c)
    lines = [r['args'][1] for r in first if r['host'] in ('movie', 'movie_flags')]
    assert lines == LINES and all(r['args'][0] == 29 and r['args'][2] == 6 for r in first if r['host'] in ('movie', 'movie_flags'))
    order = [(r['host'], r['args'] if r['host'] not in ('movie', 'movie_flags') else r['args'][1]) for r in first]
    assert order[:4] == [('get_global', ['GV_KELSRICK_DEAD']), ('get_flag', [152]), ('get_flag', [150]), ('set_flag', [152])], order[:4]
    assert order.index(('set_flag', [151])) == order.index(('movie', 358)) + 1
    assert order.index(('set_local', ['Met_Kelsrick', 'ebx'])) == order.index(('movie', 362)) + 1
    assert order[-3:] == [('place', [-1769, 5464]), ('host_f0', [150]), ('exit_room', [])], order[-3:]
    leave = calls(module, table, 0x866, 0x890)
    assert [(r['host'], r['args']) for r in leave] == [('place', [-1769, 5464]), ('host_f0', [150]), ('exit_room', [])]
    update = calls(module, table, 0x890, 0x8c4)
    assert update[0]['host'] == 'ambient_start' and update[0]['args'][:2] == [338, 170] and update[1]['args'] == [153]
    dead = calls(module, table, 0x8c4, 0x986)
    assert [(r["host"],r["args"]) for r in dead[:5]] == [("get_global",["GV_KELSRICK_DEAD"]),("get_flag",[150]),("set_global",["GV_HULINE_ALERT",1]),("get_flag",[153]),("set_flag",[153])]
    assert [r["args"][1] for r in dead if r["host"] in ("movie","movie_flags")] == list(range(375,380))
    flagged = {r['args'][1]: r['args'][3] for r in first + dead if r['host'] == 'movie_flags'}
    clips = []
    for line in LINES + list(range(375,380)):
        rec = movie(archive, f'WOMS\\CHUT\\29{line:03d}06E.VQA')
        clips.append(dict(line=line, name=rec['name'], sha256=rec['sha256'], frames=rec['frames'], width=rec['width'], height=rec['height'],
                          x=rec['x'], y=rec['y'], movie_flags=flagged.get(line, 0)))
    media = dict(background=movie(archive, 'WOMS\\CHUT\\CHUT_.VQA'), intro=movie(archive, 'WOMS\\CHUT\\HUT-APR.VQA'),
                 idle=movie(archive, 'WOMS\\CHUT\\2999906E.VQA'), idle_dead=movie(archive, 'WOMS\\CHUT\\2999506E.VQA'))
    media = {k: {f: v[f] for f in ('name', 'sha256', 'frames', 'width', 'height', 'x', 'y')} for k, v in media.items()}
    area, _, _, raw, owners, streams = source_area('L4_HJ')
    bound = [o for o in owners if o['owner_kind'] == 'region' and o['owner'] == 2750 and o['group'] == 5084]
    assert len(bound) == 1 and bound[0]['event'] == 2 and bound[0]['predicate'] == 20
    commands = [c['raw_hex'] for c in streams[0][5084]]
    assert commands[-2:] == ['0c1064000e00', '091064001500'], commands
    count, base = struct.unpack_from('<I', raw, 0xb0)[0], struct.unpack_from('<I', raw, 0xb4)[0]
    assert raw[base + count + 30 * 41:][:41].split(b'\0')[0] == b'Met_Kelsrick'
    report = dict(version=1, executable_sha256=EXE, archive_sha256=CHUT_MIX, dll_sha256=CHUT_DLL,
                  method='Static DLL disassembly with initializer-bound host slots; native room execution not replayed.',
                  room_names=names[:15],
                  jungle_entry=dict(source_sha256=area['source']['sha256'], region=2750, event=2, group=5084, predicate=20,
                                    room_control=100, room_index=14, room='CHUT', commands=commands[-2:]),
                  setup=dict(load_room=setup[0]['args'], background='chut', idle_alive=[29, 999, 6], idle_dead=[29, 995, 6]),
                  first_visit=dict(admission='Callback9: flag153 clear; GV_KELSRICK_DEAD == 0; Kelsrick_Attacked (L4_HJ local52) == 0; flags 152 and 150 clear.',
                                   start_flag=152, lines=LINES, flag_after_line={'358': 151}, local_after_line={'362': ['Met_Kelsrick', 30, 1]},
                                   place=[-1769, 5464], host_f0=150, calls=first),
                  leave=dict(place=[-1769, 5464], host_f0=150, calls=leave),
                  dead_visit=dict(admission="flag153 clear, Kelsrick dead, flag150 clear", alert_before_lines=True, start_flag=153, lines=list(range(375,380)), calls=dead),
                  first_update=dict(ambient_start=[338, 170], done_flag=153), media=media, clips=clips,
                  not_hosted=['Kelsrick_Attacked/Anyar attack branch 0x6E8 (lines 365, 1000, Soul -1, flag150)',
                              'flag150 hotspots 0x594 (66-Ancients stn) and message5 lines 366/367 (0x68B)',
                              'ambient 338 and the speaker29 actor hotspot (0x20)',
                              'control100 event5 group21322 (control112 start) and event6/20 groups 21372/21418'])
    out = ROOT / 'scripts/lol2/chut_room_source.json'
    out.write_text(json.dumps(report, indent=1) + '\n')
    print(f'PASS CHUT: room14 chut_ from g5084, first visit {LINES[0]}..{LINES[-1]} (flag152, 151 after 358, Met_Kelsrick after 362), '
          f'place(-1769,5464) f0(150); {len(clips)} clips pinned ->', out)


if __name__ == '__main__':
    main()
