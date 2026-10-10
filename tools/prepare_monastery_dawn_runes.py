#!/usr/bin/env python3
"""Pin the MLIB exit-request branch (message8, image 0x6C0) and stage its six original movies 3/663..668.

MLIB_.WOM jump table (image+0) maps message8 to 0x6C0. With get_local("Gave_Dawn_Runes") == 1, flag 0xC0 (192) clear
and Dawn installed ([0x125C]): set flag192, movies 663/664(flags 0x80)/665/666, give "70-Dampen ch", movies 667/668,
set GV_RUNES_TRANSLATED=1 and GV_DAWN_TRANSLATED_RUNES=1, set flag 0x10A (266), leave to MENT. The only writer of
Gave_Dawn_Runes (Jungle local17) is actor63's wax-runes offer g29704 (already modelled by jungle_dawn).
Also pins GLOBAL definition72 "70-Dampen ch" (handler27 = 0x979A8: consumes the held item, sets player byte 0x23ABD bit0)
and exports its icon. Local only (original media), never published.
"""
import json, struct
from pathlib import Path
import capstone
from audit_monastery_rooms import ROOT, GAME, PINNED, digest, extract, movie
from prepare_monastery_rooms import stage_patch

MOVIES = [(663, 0x80), (664, 0x80), (665, None), (666, None), (667, None), (668, None)]


def main():
    archive = (GAME / 'DAT/MLIB.MIX').read_bytes(); assert digest(archive) == PINNED['MLIB']
    dll, source = extract(archive, 'WOMS\\MLIB_.WOM')
    version, size, entry, count = struct.unpack_from('<4I', dll, 32); image = dll[48:48 + size]
    assert struct.unpack_from('<13I', image, 0)[8] == 0xb7 and image[0xb7:0xbc] == bytes([0xe8]) + struct.pack('<i', 0x6c0 - 0xbc)
    for at, text in [(0x1079, b'70-Dampen ch'), (0x1044, b'Gave_Dawn_Runes'), (0x1086, b'GV_DAWN_TRANSLATED_RUNES'), (0x101e, b'GV_RUNES_TRANSLATED'), (0x109f, b'MENT_')]:
        assert image[at:].split(b'\0')[0] == text, at
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    code = [(i.address, i.mnemonic, i.op_str) for i in md.disasm(image[0x6c0:0x834], 0x6c0)]
    calls, pushes = [], []
    for a, m, op in code:
        if m == 'push': pushes.append(op)
        elif m == 'call': calls.append((op, list(reversed(pushes)))); pushes = []
        elif m not in ('add', 'cmp', 'test', 'jne', 'je', 'jmp', 'mov', 'ret'): pushes = []
    want = [('dword ptr [0x11d4]', ['0x1044']), ('dword ptr [0x1168]', ['0xc0']), ('dword ptr [0x11a0]', []), ('dword ptr [0x1160]', ['0xc0']),
            ('dword ptr [0x1234]', []), ('dword ptr [0x1238]', ['3', '0x297', '7', '0x80']), ('dword ptr [0x1238]', ['3', '0x298', '7', '0x80']),
            ('dword ptr [0x116c]', ['3', '0x299', '7']), ('dword ptr [0x116c]', ['3', '0x29a', '7']), ('dword ptr [0x1158]', ['0x1079', '0']),
            ('dword ptr [0x116c]', ['3', '0x29b', '7']), ('dword ptr [0x116c]', ['3', '0x29c', '7']), ('dword ptr [0x11b8]', ['0x101e', '1']),
            ('dword ptr [0x11b8]', ['0x1086', '1']), ('dword ptr [0x1160]', ['0x10a']), ('dword ptr [0x1230]', [])]
    assert calls[:len(want)] == want, calls[:len(want)]
    assert ('dword ptr [0x11a4]', ['0x109f']) in calls
    cache = ROOT / 'tmp/monastery_source'; cache.mkdir(parents=True, exist_ok=True)
    out = ROOT / 'assets/lol2/generated/monastery_rooms/MLIB'
    staged = []
    for line, flags in MOVIES:
        name = 'WOMS\\MLIB\\03%03d07E.VQA' % line
        record = movie(archive, name); payload, binding = extract(archive, name); assert binding['sha256'] == record['sha256']
        src = cache / ('03%03d07E.VQA' % line); src.write_bytes(payload)
        clip = stage_patch(src, out / ('03%03d07E.ogv' % line), record); clip['line'] = line
        staged.append(clip)
    path = ROOT / 'assets/lol2/generated/monastery_rooms/rooms.json'; manifest = json.loads(path.read_text())
    manifest['rooms']['MLIB'].setdefault('sequences', {})['MLIB_EXIT_RUNES'] = staged
    path.write_text(json.dumps(manifest, indent=2) + '\n')
    # Dampen charm definition, handler and icon.
    import sys; sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_museum_key_locks import definitions, icon
    blob, base, n, names = definitions()
    from build_game_atlas import u32
    d = blob[base + 72 * 91:base + 73 * 91]; assert names[72] == '70-Dampen ch' and u32(d, 24) == 0x43F8BC0D and d[0x42] == 27
    icon(72, ROOT / 'assets/lol2/generated/monastery_dampen/dampen.png')
    report = dict(dll=source, message8=hex(0x6c0), calls=[dict(slot=c[0], args=c[1]) for c in calls], movies=[dict(line=c['line'], frames=c['frames'], samples=c['audio_samples']) for c in staged],
                  dampen=dict(definition=72, identity=0x43F8BC0D, handler=27, handler_address='0x979A8', effect='consumes held item (77ACC), sets player byte 0x23ABD bit0, calls 8619C(0x2375D,5)',
                              siblings={'28':'74-Control tokn bit2','29':'77-Lizard seal bit4','30':'78-Bestial disk bit8'}, reader='no static reader found by a full linear code sweep'),
                  setter='L4_HJ actor63 kind4 mode3 g29704 (held 72-Wax runes) writes local17 Gave_Dawn_Runes = 1')
    (ROOT / 'docs/monastery-dawn-runes-source.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS MLIB exit Dawn-runes branch pinned; staged', [(c['line'], c['frames'], c['audio_samples']) for c in staged])


if __name__ == '__main__':
    main()
