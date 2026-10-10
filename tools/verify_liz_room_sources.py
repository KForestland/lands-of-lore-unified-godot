#!/usr/bin/env python3
"""Source evidence for the village LIZ room (docs/liz-room.md). Independent of grok/liz_room_review_20261010.

- VILLAGE_.WOM hotspot handler 0x560: hotspot 3 -> room("liz_") with no flag test; hotspot 2 -> "can_" only while
  flag267 is clear. VILLAGE setup registers hotspot 3 at (425,211)-(576,310).
- LIZ_.WOM host slots are bound by the DLL initializer (`mov edx,[eax+off]; mov [slot],edx`). Their host targets are
  resolved through LOLG.DAT fixups (the same table as tools/prepare_hive_rune_speech.py).
- Setup 0x47C: get_flag(268); if clear load_room("LIZTRAN",1,0); set_flag(268) on both paths; five hotspots.
- Click 0x5A7:
  - hotspot 0 while flag162 is clear: set_flag(162), movie(100,2,24), give_item("71-Wax",0);
  - hotspots 1..4: quip(0x100/0x200/0x400/0x800).
- Callback 8 at 0x63D: room("VILLAGE_"), exit_room. Callback 9 at 0x654: ambient_start(367,90), movie(2,59,24).
- movie(100,2,24) and movie(2,59,24) are sound-bank requests (speaker biases 268/141, proven by the rune-speech replay).
  Trailer -> request -> bank record names and hashes.
Writes docs/liz-room-checks.json and scripts/lol2/liz_room_source.json (numbers and names only).
"""
import hashlib, json, re, struct
from pathlib import Path
from audit_hive_rune_rooms import ROOT, GAME, extract, digest, fixups, u32, capstone
from prepare_hive_wax import entry
from audit_monastery_rooms import movie

md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
EXE = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
LIZ_MIX = '0b81a4fb6ec55ca2c4dc88ff2ec7f89c8012d76b98375c33022c56f83c653c3d'
LIZ_DLL = 'd08a4dd833d1c7252e9e5181aa2a81ddadb6162136da058350f2d5bf84801e77'
VILLAGE_MIX = '497fa122ad5c48dbbd6f651f826f57383436a3962cd67d4b175ffd636a25548b'
VILLAGE_DLL = 'a2eba4575456458a3b6597149456ac695674bca6b5cc89c3f8e445eb428bfa20'
BANK = 'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6'
HOSTS = {0x18: ('hotspot', 0xef028), 0x1c: ('remove_hotspot', 0xef07c), 0x40: ('give_item', 0xef2b8), 0x48: ('set_flag', 0xef32c),
         0x50: ('get_flag', 0xef380), 0x54: ('movie', 0xee784), 0x68: ('exit_room', 0xef464), 0x88: ('room', 0xef558),
         0xbc: ('load_room', 0xef704), 0xfc: ('quip', 0xf133c), 0x100: ('reset_trigger_bits', 0xf14cc),
         0x138: ('ambient_start', 0xf1654), 0x13c: ('ambient_stop', 0xf16d8)}


def item_identity(name):
    """Host 154880 (copied from audit_act_one_item_producers.identity, which needs unicorn to import)."""
    b = name.encode(); h = 0
    for k in range(len(b) // 4): h = ((h << 1 | h >> 31) + struct.unpack_from('<I', b, 4 * k)[0]) & 0xffffffff
    r = len(b) % 4
    if r:
        t = 0
        for c in b[len(b) - r:]: t = ((t & 0xffffff00 | c) >> 8 | (c << 24)) & 0xffffffff
        s = (4 - r) * 8; t = (t >> s | t << (32 - s)) & 0xffffffff
        h = ((h << 1 | h >> 31) + t) & 0xffffffff
    return h


def module_of(mix, wom, mix_sha, dll_sha):
    archive = (GAME / 'DAT' / mix).read_bytes(); assert digest(archive) == mix_sha, mix
    dll, rec = extract(archive, wom); assert digest(dll) == dll_sha, wom
    return archive, dll[48:]


def bindings(module, exe):
    init = list(md.disasm(module[0xf6:0x47c], 0xf6))
    le = 0x39024 + u32(exe, 0x39060); first = u32(exe, le + u32(exe, le + 0x40) + 108)
    out = {}
    for k, row in enumerate(init):
        mm = re.match(r'dword ptr \[(0x[0-9a-f]+)\], (edx|eax)$', row.op_str)
        pm = re.match(r'(edx|eax), dword ptr \[eax \+ (0x[0-9a-f]+)\]$', init[k - 1].op_str) if k else None
        if mm and pm and mm.group(2) != pm.group(1): pm = None
        if row.mnemonic == 'mov' and mm and pm:
            offset = int(pm.group(2), 16); address = 0xe92c + offset
            rel = fixups(exe, le, first - 1 + address // 4096)[address % 4096]
            out[int(mm.group(1), 16)] = dict(offset=offset, target=rel['target_offset'] + 0x59024 if rel['target_object'] == 2 else None)
    return out


def trace(module, slots, start, end):
    names = {s: HOSTS[b['offset']][0] for s, b in slots.items() if b['offset'] in HOSTS}
    rows, pushes = [], []
    for i in md.disasm(module[start:end], start):
        if i.mnemonic == 'push': pushes.append(i.op_str)
        elif i.mnemonic == 'call':
            mm = re.match(r'dword ptr \[(0x[0-9a-f]+)\]$', i.op_str)
            args = []
            for p in reversed(pushes):
                if p.startswith('0x') and 0x600 <= int(p, 16) < len(module) and 0x20 < module[int(p, 16)] < 0x7f and module[int(p, 16) + 1] != 0:
                    args.append(module[int(p, 16):].split(b'\0')[0].decode())
                else: args.append(int(p, 16) if p.startswith('0x') else (int(p) if p.lstrip('-').isdigit() else p))
            rows.append((names.get(int(mm.group(1), 16), hex(int(mm.group(1), 16))) if mm else 'near:' + i.op_str, args)); pushes = []
        elif i.mnemonic in ('jmp', 'ret'): pushes = []
    return rows


def window(module, start, end):
    text = [f'{i.address:04x} {i.mnemonic} {i.op_str}' for i in md.disasm(module[start:end], start)]
    return dict(start=hex(start), end=hex(end), sha256=hashlib.sha256(module[start:end]).hexdigest(), instructions=len(text))


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes(); assert digest(exe) == EXE
    liz_archive, liz = module_of('LIZ.MIX', 'WOMS\\LIZ_.WOM', LIZ_MIX, LIZ_DLL)
    village_archive, village = module_of('VILLAGE.MIX', 'WOMS\\VILLAGE_.WOM', VILLAGE_MIX, VILLAGE_DLL)
    ls = bindings(liz, exe); vs = bindings(village, exe)
    for slot, off in {0x714: 0x18, 0x718: 0x1c, 0x73c: 0x40, 0x744: 0x48, 0x74c: 0x50, 0x750: 0x54, 0x768: 0x68, 0x788: 0x88, 0x7bc: 0xbc,
                      0x7fc: 0xfc, 0x800: 0x100, 0x838: 0x138, 0x83c: 0x13c}.items():
        assert ls[slot]['offset'] == off and ls[slot]['target'] == HOSTS[off][1], hex(slot)
    for slot, off in {0x6b8: 0x88, 0x698: 0x68, 0x67c: 0x50, 0x644: 0x18}.items():
        assert vs[slot]['offset'] == off and vs[slot]['target'] == HOSTS[off][1], hex(slot)
    # VILLAGE: setup hotspot 3 rect and the click handler.
    vsetup = trace(village, vs, 0x47c, 0x527)
    rects = [a for k, a in vsetup if k == 'hotspot']
    assert rects[2] == [2, 244, 220, 386, 310] and rects[3] == [3, 425, 211, 576, 310], rects
    vclick = [r for r in trace(village, vs, 0x560, 0x5c1)]
    # hotspot3's room("liz_") shares hotspot2's call site (jmp 0x580), so the trace shows only the "can_" call.
    assert ('get_flag', [267]) in vclick and ('room', ['can_']) in vclick
    hs3 = [f'{i.mnemonic} {i.op_str}' for i in md.disasm(village[0x591:0x59d], 0x591)]
    assert hs3 == ['cmp eax, 3', 'jne 0x59d', 'push 0x624', 'jmp 0x580'], hs3
    assert village[0x624:].split(b'\0')[0] == b'liz_' and village[0x61f:].split(b'\0')[0] == b'can_'
    hs2 = [f'{i.mnemonic} {i.op_str}' for i in md.disasm(village[0x564:0x591], 0x564)]
    assert hs2[:3] == ['cmp eax, 2', 'jne 0x591', 'push 0x10b'] and 'push 0x61f' in hs2
    # LIZ setup, click, exit, first update.
    setup = trace(liz, ls, 0x47c, 0x54d)
    # The third load_room argument is `push eax`, reached only when get_flag returned 0 (test eax,eax; jne): it is 0.
    assert setup[:3] == [('get_flag', [268]), ('load_room', ['LIZTRAN', 1, 'eax']), ('set_flag', [268])], setup[:3]
    jumps = {i.address: f'{i.mnemonic} {i.op_str}' for i in md.disasm(liz[0x48a:0x4a4], 0x48a)}
    assert jumps[0x48a] == 'test eax, eax' and jumps[0x48c] == 'jne 0x49f' and jumps[0x49f] == 'push 0x10c'  # set_flag on both paths
    liz_rects = [a for k, a in setup if k == 'hotspot']
    assert liz_rects == [[0, 91, 282, 146, 339], [1, 177, 151, 217, 221], [2, 290, 238, 344, 316], [3, 404, 244, 472, 322], [4, 220, 198, 365, 234]]
    click = trace(liz, ls, 0x5a7, 0x63d)
    # The prologue's `push ebx` precedes the first push; ebx holds the hotspot index (0 on this path).
    assert click[0] == ('get_flag', [162, 'ebx']) and click[1:4] == [('set_flag', [162]), ('movie', [100, 2, 24]), ('give_item', ['71-Wax', 'ebx'])], click[:4]
    quips = [f'{i.mnemonic} {i.op_str}' for i in md.disasm(liz[0x5f0:0x63d], 0x5f0)]
    for value in ('0x100', '0x200', '0x400', '0x800'): assert f'push {value}' in quips
    assert sum(1 for q in quips if q == 'call dword ptr [0x7fc]') == 2 and 'jmp 0x611' in quips and not any('0x788' in q or '0x768' in q for q in quips)
    exit8 = trace(liz, ls, 0x63d, 0x654); assert exit8 == [('room', ['VILLAGE_']), ('exit_room', [])], exit8
    first9 = trace(liz, ls, 0x654, 0x67b); assert first9 == [('ambient_start', [367, 90]), ('movie', [2, 59, 24])], first9
    assert liz[0x6ec:].split(b'\0')[0] == b'71-Wax'
    identity = item_identity('71-Wax'); assert identity == 0xAE5ADACF, hex(identity)
    # Media: background + transition inside LIZ.MIX.
    media = {}
    for name in ('WOMS\\LIZ\\LIZ_.VQA', 'WOMS\\LIZ\\LIZTRAN.VQA'):
        rec = movie(liz_archive, name); media[name] = dict(sha256=rec['sha256'], frames=rec['frames'], width=rec['width'], height=rec['height'])
    assert media['WOMS\\LIZ\\LIZ_.VQA']['sha256'] == '9bc7243cd3a62d49fa296d8727348c868de8351bfc18206d074aea45e379913f'
    assert media['WOMS\\LIZ\\LIZTRAN.VQA']['sha256'] == '28be770c9d70fa80917a489a2d15f5d00f95320c497c8a618a0b90b103080708' and media['WOMS\\LIZ\\LIZTRAN.VQA']['frames'] == 160
    # Sound-bank cues (speaker biases from the replayed EE784 rule).
    raw = entry('LOCALLNG.MIX', 1570429112); assert digest(raw) == BANK
    cues = {}
    for (speaker, line), bias in [((100, 2), 268), ((2, 59), 141)]:
        index = line + bias; request = struct.unpack_from('<H', raw, len(raw) - 808 + index * 2)[0]
        row = raw[u32(raw, 0x25c) + request * 60:][:60]; audio = raw[u32(row, 0):][:u32(row, 4)]
        rate, packed, decoded, flags, codec = struct.unpack_from('<HIIBB', audio); assert len(audio) == packed + 12 and codec == 99
        cues[f'{speaker}:{line}'] = dict(trailer_index=index, request=request, bank_record=row[16:].split(b'\0')[0].decode(), sha256=digest(audio), bytes=len(audio), rate=rate)
    assert cues['100:2']['request'] == 221 and cues['100:2']['bank_record'].lower() == '0100224e.aud' and cues['100:2']['sha256'] == '449f860e1be353a8bb98f332136000491e6cbf21d7dd35fc35206139c5d381c8'
    assert cues['2:59']['request'] == 247 and cues['2:59']['bank_record'].lower() == '0120224e.aud' and cues['2:59']['sha256'] == 'd8f5a86c84abdba61db94852884c03729fd5a398be76e46a1dd10dd1bd526f56'
    source = dict(version=1, room='LIZ', source_room='liz_', village_hotspot=dict(index=3, rect=[425, 211, 576, 310], flag_test=None),
                  intro=dict(flag=268, movie='WOMS\\LIZ\\LIZTRAN.VQA'), background='WOMS\\LIZ\\LIZ_.VQA',
                  hotspots=[dict(index=r[0], rect=r[1:]) for r in liz_rects],
                  wax=dict(hotspot=0, flag=162, cue='100:2', item='71-Wax', identity=identity, order=['set_flag 162', 'cue 100:2', 'give_item 71-Wax']),
                  entry_cue='2:59', exit='VILLAGE', cues=cues,
                  not_hosted=['quip 0x100/0x200/0x400/0x800 on hotspots 1-4 (lines unknown)', 'callback11 host 0xE8/0x134', 'ambient 367',
                              'load_room extra arguments 1, 0'])
    (ROOT / 'scripts/lol2/liz_room_source.json').write_text(json.dumps(source, indent=1) + '\n')
    report = dict(executable_sha256=EXE, liz_mix_sha256=LIZ_MIX, liz_dll_sha256=LIZ_DLL, village_mix_sha256=VILLAGE_MIX, village_dll_sha256=VILLAGE_DLL,
                  sound_bank_sha256=BANK, liz_slots={hex(k): dict(offset=hex(v['offset']), name=HOSTS[v['offset']][0], target=hex(v['target'])) for k, v in ls.items() if v['offset'] in HOSTS},
                  windows={k: window(liz, a, z) for k, (a, z) in {'setup': (0x47c, 0x54d), 'click': (0x5a7, 0x63d), 'exit8': (0x63d, 0x654), 'first9': (0x654, 0x67b)}.items()}
                  | {'village_click': window(village, 0x560, 0x5c1)},
                  setup=setup, click=click[:4], exit8=exit8, first9=first9, media=media, cues=cues, wax_identity=hex(identity), passed=True)
    (ROOT / 'docs/liz-room-checks.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS LIZ room sources: VILLAGE hotspot3 -> liz_ (no flag), setup flag268/LIZTRAN/5 hotspots, wax flag162 -> cue 100:2 -> 71-Wax (%s), '
          'quips 1-4, exit8 VILLAGE_, first-update cue 2:59, bank records %s' % (hex(identity), [c['bank_record'] for c in cues.values()]))


if __name__ == '__main__':
    main()
