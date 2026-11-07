#!/usr/bin/env python3
"""Source evidence for the Thieves' Den room chain (docs/thieves-den.md): TEXT (yard), TCEL (cellar), TDOOR (slot
door) and TINT (Mauri's den), read from the original room DLLs in DAT/<ROOM>.MIX.

For each room the DLL (`WOMS\\<ROOM>_.WOM`, a 48-byte "linear executable dll" header + module) is extracted and its
host slots are bound as the DLL initializer does (`mov edx,[eax+off]; mov [slot],edx`, 0xF6..0x47C). Each slot's host
target comes from the LOLG.DAT LE fixups of the host table at 0xE92C (the same resolution as
tools/verify_liz_room_sources.py and tools/prepare_hive_rune_speech.py). The 13-entry dispatcher at module offset 0
names the callback functions. Every call through a named slot is listed per callback with its literal arguments
(pushed immediates and module strings) and module offset. Media requests `movie/movie_flags/idle(speaker, line, view)`
are resolved to archive entries by the Westwood name hash of `WOMS\\<ROOM>\\SSLLLVVE.VQA|AUD`; the hash collides across
names, so an entry is named only by a request the DLL makes.

Writes scripts/lol2/thieves_den_source.json (numbers and names only; no media) and docs/thieves-den-checks.json.
Explicit inputs:
  python3 tools/verify_thieves_den_sources.py --game GAME [--exe GAME/LOLG.DAT] [--root REPO]
Published helpers only (tools/lol2_source_format, tools/lol2_movie_format, tools/prepare_cave_special_media.fixups)
plus capstone for the disassembly.
"""
import argparse, hashlib, json, re, struct, sys
from pathlib import Path
import capstone
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lol2_source_format import parse_mix, u32
from lol2_movie_format import ww_hash_v1
from prepare_cave_special_media import fixups

md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
ROOT = Path(__file__).resolve().parents[1]
EXE_SHA256 = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'  # LOLG.DAT
ARCHIVES = {'TEXT': 'a2ba8ba8e18c5ebeaea51ec8e8c36eae865f839341b16b7597ece01272f51302',
            'TCEL': '27614f82095f3319344c8e4dcccdfe5be7ceeb1d2aa0f6b0dd06ae4c04b4be5d',
            'TDOOR': '36672526f1295e3ed86f01eee167f883e76d4d12ed976262c1c5048ed75f23f0',
            'TINT': '838c78763aabeb13c48bcfb4ec2804423a333eba535f9c0371c884af7a89c37f'}
HOST_NAMES = {0x08: 'load_shapes', 0x0c: 'free_shapes', 0x10: 'shape_hotspot', 0x14: 'remove_shape_hotspot',
              0x18: 'hotspot', 0x1c: 'remove_hotspot', 0x20: 'actor', 0x28: 'idle', 0x40: 'give_item',
              0x44: 'take_held_item', 0x48: 'set_flag', 0x4c: 'clear_flag', 0x50: 'get_flag', 0x54: 'movie',
              0x5c: 'damage', 0x68: 'exit_room', 0x70: 'get_global', 0x74: 'holding_item', 0x80: 'arm_timer',
              0x84: 'cancel_timer', 0x88: 'room', 0x9c: 'set_global', 0xa4: 'held_item_state',
              0xa8: 'held_item_is_magic', 0xb4: 'set_local', 0xb8: 'get_local', 0xbc: 'load_room', 0xe0: 'place',
              0xe8: 'random', 0xf0: 'set_heading', 0x114: 'cursor_show', 0x118: 'cursor_hide', 0x11c: 'movie_flags',
              0x120: 'add_fighting_xp', 0x134: 'sfx', 0x138: 'ambient_start', 0x13c: 'ambient_stop'}
# Documented host addresses (the port's verify_* HOSTS tables; THIEVES_DEN_DECODE §2) for the slots that matter here.
HOST_ADDRESSES = {0x18: 0xef028, 0x1c: 0xef07c, 0x40: 0xef2b8, 0x48: 0xef32c, 0x4c: 0xef358, 0x50: 0xef380,
                  0x54: 0xee784, 0x68: 0xef464, 0x88: 0xef558, 0xbc: 0xef704, 0x11c: 0xeed64, 0x138: 0xf1654,
                  0x13c: 0xf16d8, 0xe0: 0xed370, 0xf0: 0xed398, 0x74: 0xef4c0, 0xa8: 0xef698, 0xa4: 0xef664,
                  0x44: 0xef304, 0x84: 0xef530}
CALLBACKS = {1: 'setup', 2: 'teardown', 3: 'sprite_click', 4: 'hotspot_click', 5: 'offer', 6: 'spell', 7: 'weapon',
             8: 'leave', 9: 'first_update', 10: 'timer', 11: 'event_sound', 12: 'completion'}
ROOMS = ['TEXT', 'TCEL', 'TDOOR', 'TINT']
# Register arguments whose value the preceding instructions fix (documented, checked against the listing):
# TINT 0x58E shape_hotspot(eax, 528, 145, eax) follows get_flag(21) -> test eax / jne, so eax == 0 (sprite 0, frame 0);
# TINT 0x757 movie(eax, 32, 24) is hotspot 3's branch of the click switch, where eax == 2 (speaker 2, as hotspot 2's
# literal branch at 0x749).
REGISTER_VALUES = {('TINT', 0x58e): {'eax': 0}, ('TINT', 0x757): {'eax': 2}}


def digest(b): return hashlib.sha256(b).hexdigest()


def slots(module):
    rows = list(md.disasm(module[0xf6:0x47c], 0xf6)); out = {}
    for k in range(1, len(rows)):
        store = re.match(r'dword ptr \[(0x[0-9a-f]+)\], (edx|eax)$', rows[k].op_str)
        load = re.match(r'(edx|eax), dword ptr \[eax(?: \+ (0x[0-9a-f]+|[0-9]+))?\]$', rows[k - 1].op_str)
        if rows[k].mnemonic == 'mov' and store and load and store.group(2) == load.group(1):
            out[int(store.group(1), 16)] = int(load.group(2) or '0', 0)
    return out


def host_table(exe):
    le = 0x39024 + u32(exe, 0x39060); first = u32(exe, le + u32(exe, le + 0x40) + 108)
    table = {}
    for off in range(0, 0x160, 4):
        address = 0xe92c + off
        rel = fixups(exe, le, first - 1 + address // 4096).get(address % 4096)
        if rel and rel['target_object'] == 2: table[off] = rel['target_offset'] + 0x59024
    return table


def module_string(module, p):
    if 0x400 <= p < len(module) and 0x20 < module[p] < 0x7f:
        s = module[p:].split(b'\0')[0]
        if len(s) >= 2 and all(0x20 <= c < 0x7f for c in s): return s.decode()
    return None


def callbacks(module):
    table = struct.unpack_from('<13I', module, 0); out = {}
    for n, stub in enumerate(table):
        target = None
        for i in md.disasm(module[stub:stub + 40], stub):
            if i.mnemonic == 'call' and i.op_str.startswith('0x'): target = int(i.op_str, 16); break
            if i.mnemonic == 'ret': break
        out[n] = target
    return out


IMMEDIATE = re.compile(r'^(0x[0-9a-f]+|-?\d+)$')


def calls(module, size, names):
    """Every call through a named slot from 0x47C to the module end: (name, args, offset, via). Arguments are the
    immediates pushed since the previous call/jump/ret, innermost first; strings are resolved from the module. A
    branch that pushes part of the arguments and then jumps into a shared push/call tail (TDOOR 0x5E3, TINT 0x74B) is
    recorded as its own site: offset = the jump, via = the shared call."""
    insns = list(md.disasm(module[0x47c:size], 0x47c)); at = {i.address: k for k, i in enumerate(insns)}
    def literal(p):
        if IMMEDIATE.match(p):
            v = int(p, 0); s = module_string(module, v)
            return s if s else (v - (1 << 32) if v >= 1 << 31 else v)
        return p
    def named_call(i):
        mm = re.match(r'dword ptr \[(0x[0-9a-f]+)\]$', i.op_str) if i.mnemonic == 'call' else None
        return names.get(int(mm.group(1), 16)) if mm else None
    rows, pushes = [], []
    for i in insns:
        if i.mnemonic == 'push': pushes.append(i.op_str)
        elif i.mnemonic == 'call':
            name = named_call(i)
            if name: rows.append((name, [literal(p) for p in reversed(pushes)], i.address, None))
            pushes = []
        elif i.mnemonic == 'jmp':
            if pushes and IMMEDIATE.match(i.op_str) and int(i.op_str, 0) in at:
                tail, k, hops = [], at[int(i.op_str, 0)], 0
                while k < len(insns) and hops < 8:
                    j = insns[k]
                    if j.mnemonic == 'push': tail.append(j.op_str); k += 1; continue
                    if j.mnemonic == 'jmp' and IMMEDIATE.match(j.op_str) and int(j.op_str, 0) in at: k = at[int(j.op_str, 0)]; hops += 1; continue
                    name = named_call(j)
                    if name: rows.append((name, [literal(p) for p in reversed(pushes + tail)], i.address, j.address))
                    break
            pushes = []
        elif i.mnemonic == 'ret': pushes = []
    return rows


SOUND_BANK = (1570429112, 'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6')  # LOCALLNG.MIX entry key, sha256
LOCALLNG_SHA256 = '113a35353cac0344db298616ea4eff9fd254ab83494079ce7777560b655ee2d8'
SPEAKER2_BIAS = 141  # trailer index = line + 141 (tools/prepare_hive_rune_speech.py replay)


def bank_cue(bank, line):
    """Sound-bank record for a speaker-2 view-24 request (as prepare_magic_shop_offers.bank_audio)."""
    request = struct.unpack_from('<H', bank, len(bank) - 808 + (line + SPEAKER2_BIAS) * 2)[0]; assert request < u32(bank, 0x258)
    row = bank[u32(bank, 0x25c) + request * 60:][:60]; audio = bank[u32(row, 0):][:u32(row, 4)]
    rate, packed, decoded, flags, codec = struct.unpack_from('<HIIBB', audio); assert len(audio) == packed + 12 and codec == 99
    return dict(request=request, trailer_index=line + SPEAKER2_BIAS, source_name=row[16:].split(b'\0')[0].decode(), bytes=len(audio), sha256=digest(audio), rate=rate, decoded=decoded)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True); p.add_argument('--exe', type=Path)
    p.add_argument('--root', type=Path, default=ROOT)
    a = p.parse_args()
    exe = (a.exe or a.game / 'LOLG.DAT').read_bytes(); assert digest(exe) == EXE_SHA256, 'LOLG.DAT'
    table = host_table(exe)
    locallng = (a.game / 'LOCALLNG.MIX').read_bytes(); assert digest(locallng) == LOCALLNG_SHA256, 'LOCALLNG.MIX'
    bank_row = next(e for e in parse_mix(locallng) if e['key'] == SOUND_BANK[0]); bank = locallng[bank_row['offset']:][:bank_row['size']]
    assert digest(bank) == SOUND_BANK[1], 'sound bank'
    for off, want in HOST_ADDRESSES.items(): assert table.get(off) == want, f'host slot {off:#x}: {table.get(off)}'
    source = {'version': 1, 'executable_sha256': EXE_SHA256, 'host_slots': {f'{k:#x}': {'name': HOST_NAMES.get(k, f'h{k:x}'), 'address': f'{v:#x}'} for k, v in sorted(table.items()) if k in HOST_NAMES}, 'rooms': {}}
    checks = {'passed': True, 'rooms': {}}
    for room in ROOMS:
        archive = (a.game / 'DAT' / f'{room}.MIX').read_bytes(); assert digest(archive) == ARCHIVES[room], f'DAT/{room}.MIX is not the pinned original'
        entries = parse_mix(archive); by_key = {e['key']: e for e in entries}
        dll_row = by_key[ww_hash_v1(f'WOMS\\{room}_.WOM')]; dll = archive[dll_row['offset']:][:dll_row['size']]
        assert dll[:32] == b'This is a linear executable dll\n', room
        version, size, entry, count = struct.unpack_from('<4I', dll, 32); module = dll[48:48 + size]
        sl = slots(module); names = {s: HOST_NAMES[o] for s, o in sl.items() if o in HOST_NAMES}
        cbs = callbacks(module); targets = sorted(t for t in cbs.values() if t)
        rows = calls(module, size, names)
        rows = [(name, [REGISTER_VALUES.get((room, off), {}).get(x, x) if isinstance(x, str) else x for x in args], off, via) for name, args, off, via in rows]
        def owner(offset):
            best = None
            for n, t in cbs.items():
                if t and t <= offset and (best is None or t > cbs[best]): best = n
            return best
        per_callback = {}
        for name, args, offset, via in rows:
            n = owner(offset); per_callback.setdefault(str(n), []).append([name, args, f'{offset:#x}'] + ([f'{via:#x}'] if via else []))
        # Hotspots, shapes, actor and placements from literal calls.
        hotspots = [dict(index=args[0], rect=args[1:5]) for name, args, _, _ in rows if name == 'hotspot' and len(args) >= 5 and all(isinstance(x, int) for x in args[:5])]
        shapes = [dict(index=args[0], x=args[1], y=args[2], frame=args[3]) for name, args, _, _ in rows if name == 'shape_hotspot' and len(args) >= 4 and all(isinstance(x, int) for x in args[:4])]
        actors = [dict(index=args[0], speaker=args[1], x=args[2], y=args[3], width=args[4], height=args[5]) for name, args, _, _ in rows if name == 'actor' and len(args) >= 6 and all(isinstance(x, int) for x in args[:6])]
        places = [dict(x=args[0], y=args[1], offset=f'{off:#x}') for name, args, off, _ in rows if name == 'place' and len(args) >= 2]
        headings = [dict(heading=args[0], offset=f'{off:#x}') for name, args, off, _ in rows if name == 'set_heading' and args and isinstance(args[0], int)]
        # Media requests: (speaker, line, view) triples from movie/movie_flags/idle; resolved to archive entries.
        requests = {}
        for name, args, off, _ in rows:
            if name in ('movie', 'movie_flags', 'idle') and len(args) >= 3 and all(isinstance(x, int) for x in args[:3]):
                key = f'{args[0]}:{args[1]}:{args[2]}'
                req = requests.setdefault(key, dict(request=args[:3], flags=sorted(set()), sites=[], kind=name))
                if name == 'movie_flags' and len(args) >= 4 and isinstance(args[3], int): req['flags'] = sorted(set(req['flags']) | {args[3]})
                req['sites'].append(f'{off:#x}')
                if name == 'idle': req['kind'] = 'idle'
        claimed = {}
        for key, req in requests.items():
            s, l, v = req['request']
            if s == 2 and v == 24:
                req['sound_bank'] = bank_cue(bank, l); continue
            for ext in ('VQA', 'AUD'):
                n = f'WOMS\\{room}\\{s:02d}{l:03d}{v:02d}E.{ext}'; k = ww_hash_v1(n)
                if k in by_key:
                    e = by_key[k]; data = archive[e['offset']:][:e['size']]
                    req[ext.lower()] = dict(name=n, key=k, size=e['size'], sha256=digest(data))
                    if ext == 'VQA':
                        at = data.index(b'VQHD'); h = data[at + 8:at + 50]
                        frames, width, height = struct.unpack_from('<HHH', h, 4); x, y = struct.unpack_from('<HH', h, 18)
                        req['vqa'].update(frames=frames, width=width, height=height, fps=h[12], x=x, y=y, codebook_parts=h[13])
                    assert claimed.setdefault(k, key) == key, f'{room}: entry {k} claimed by {claimed[k]} and {key}'
        # Luther's replies: (1, line, 6) AUD present for lines requested with speaker 31 (THIEVES_DEN_DECODE §6).
        replies = {}; ambiguous = {}
        for key, req in requests.items():
            s, l, v = req['request']
            if s != 31: continue
            n = f'WOMS\\{room}\\01{l:03d}06E.AUD'; k = ww_hash_v1(n)
            if k in by_key and k in claimed and claimed[k] != f'1:{l}:6': ambiguous[str(l)] = dict(name=n, key=k, also=claimed[k], after_flags=req['flags'])
            if k in by_key and k not in claimed:
                e = by_key[k]; data = archive[e['offset']:][:e['size']]
                replies[str(l)] = dict(name=n, key=k, size=e['size'], sha256=digest(data), after_flags=req['flags'])
                claimed[k] = f'reply:{l}'
        fixed = {}
        for n in [f'WOMS\\{room}\\{room}_.VQA', f'WOMS\\{room}\\CELLAR.VQA', f'WOMS\\{room}\\TINTTRAN.VQA', f'WOMS\\{room}\\THFSHAPE.SHP']:
            k = ww_hash_v1(n)
            if k in by_key:
                e = by_key[k]; data = archive[e['offset']:][:e['size']]
                rec = dict(name=n, key=k, size=e['size'], sha256=digest(data))
                if n.endswith('.VQA'):
                    at = data.index(b'VQHD'); h = data[at + 8:at + 50]
                    frames, width, height = struct.unpack_from('<HHH', h, 4)
                    rec.update(frames=frames, width=width, height=height, fps=h[12], codebook_parts=h[13])
                fixed[n.split('\\')[-1]] = rec; claimed[k] = n
        unnamed = []
        for e in entries:
            if e['key'] in claimed or e['key'] == dll_row['key']: continue
            cands = [f'{sp:02d}{l:03d}{v:02d}E.{ext}' for sp in (1, 2, 31) for l in range(1000) for v in (0, 6, 10, 24) for ext in ('VQA', 'AUD') if ww_hash_v1(f'WOMS\\{room}\\{sp:02d}{l:03d}{v:02d}E.{ext}') == e['key']]
            unnamed.append(dict(key=e['key'], size=e['size'], sha256=digest(archive[e['offset']:][:e['size']]), name_candidates=cands))
        strings = sorted({a for _, args, _, _ in rows for a in args if isinstance(a, str) and not re.match(r'^(e[abcd]x|e[sd]i|e[bs]p)$', a)})
        flags = {'set': sorted({args[0] for name, args, _, _ in rows if name == 'set_flag' and args and isinstance(args[0], int)}),
                 'cleared': sorted({args[0] for name, args, _, _ in rows if name == 'clear_flag' and args and isinstance(args[0], int)}),
                 'read': sorted({args[0] for name, args, _, _ in rows if name == 'get_flag' and args and isinstance(args[0], int)})}
        named = {'globals_read': sorted({args[0] for name, args, _, _ in rows if name == 'get_global' and args and isinstance(args[0], str)}),
                 'locals_read': sorted({args[0] for name, args, _, _ in rows if name == 'get_local' and args and isinstance(args[0], str)}),
                 'locals_set': sorted({args[0] for name, args, _, _ in rows if name == 'set_local' and args and isinstance(args[0], str)}),
                 'items_given': sorted({args[0] for name, args, _, _ in rows if name == 'give_item' and args and isinstance(args[0], str)}),
                 'rooms': sorted({args[0] for name, args, _, _ in rows if name in ('room', 'load_room') and args and isinstance(args[0], str)})}
        source['rooms'][room] = dict(archive=f'DAT/{room}.MIX', archive_sha256=digest(archive), dll=dict(name=f'WOMS\\{room}_.WOM', sha256=digest(dll), module_size=size, fixups=count),
                                     callbacks={str(n): dict(name=CALLBACKS.get(n, f'cb{n}'), offset=f'{t:#x}' if t else None) for n, t in cbs.items() if n},
                                     slots={f'{s:#x}': HOST_NAMES.get(o, f'h{o:x}') for s, o in sorted(sl.items())},
                                     hotspots=hotspots, shape_hotspots=shapes, actors=actors, placements=places, headings=headings,
                                     flags=flags, **named, calls=per_callback, requests=requests, luther_replies=replies, ambiguous_replies=ambiguous, fixed_entries=fixed,
                                     unnamed_entries=unnamed, strings=strings)
        checks['rooms'][room] = dict(archive_sha256=digest(archive), dll_sha256=digest(dll), host_calls=len(rows), requests=len(requests), resolved=sum(1 for r in requests.values() if 'vqa' in r or 'aud' in r or 'sound_bank' in r), replies=len(replies), unnamed=len(unnamed))
    out = a.root / 'scripts/lol2/thieves_den_source.json'
    out.write_text(json.dumps(source, indent=1) + '\n')
    checks['source'] = 'scripts/lol2/thieves_den_source.json'; checks['source_sha256'] = digest(out.read_bytes())
    checks['scope'] = ('Static read of the four den DLLs: slot bindings through LOLG.DAT fixups, dispatcher targets, every host call with literal arguments per callback, hotspot/shape/actor geometry, placements, flag/global/local/item names and media requests resolved to pinned archive entries. Control flow (branch conditions) is documented in docs/thieves-den.md from the listings; it is not replayed here.')
    (a.root / 'docs/thieves-den-checks.json').write_text(json.dumps(checks, indent=1) + '\n')
    for room, c in checks['rooms'].items(): print(room, c)
    print('PASS thieves den sources:', out)


if __name__ == '__main__': main()
