#!/usr/bin/env python3
"""Pin the Huline Jungle plank bridge (L4_HJ controls 210/212/213/214, assembly 211) as a source contract.

Source facts (read-only; AI_COMMS/act1_completion_20261017/BRIDGE_EVENT5_CONTRACT_20261025.md):
- Producer: the player's support owner. D39C3 compares player +7D with +79 (the object the player stands on, set by
  the vertical support classifier, docs/control-contact-admission-checks.json); on a change the old owner gets
  AD8E0(kind5, value5) and the new owner ADA30(records, player byte +0x1AB = form: 0 human, 1 beast, 2 lizard).
  ADA30 admits kind5 records of values 4..12 through jump table 0x549E8 (pinned by prepare_cave_entrance_death):
  4 always, 7 form==2, 8 form==0, 9 form==1, 10 form!=2, 11 form!=0, 12 form!=1, 5/6 never.
- Plank 210 kind5 value9 (beast steps on it), predicate206 (owner state == 0), in source order:
  g26868 local50=1, op197 region3032 sub3 (sets region bit1), op5 210 selector1, op9 assembly211 property3 (link),
  op9 props 965/961/962/964/963 property3, op16 210 state1 (twice); g26940 op20 sound452 on 210.
- Planks 212/213/214 kind5 value10 (human or beast steps on them), no predicate: op20 sounds 779/777/781.
- Assembly op5 (vtable5484 +B0 -> 5D510) only writes the mode byte +3D and the child count +3B (5A8AC counts children
  with mask bit 1<<mode): template25 in mode 1 keeps only children 49..52 (mask 3, the posts). Placement flags are not
  touched, and the mode-2 box collision (5BD90: template bytes 0x2D/0x2F/0x30/0x31) does not read the mode, so the
  plank stays solid after the break.
- Assembly 211 (template22) is placed absent (flags bit 0x1000) and linked by the break.
Runtime delivery and validation are documented separately in docs/jungle-bridge-break.md. This producer proves
source data, not host integration or rendered behavior.
Usage: prepare_jungle_bridge_break.py --game GAME [--output scripts/lol2/jungle_bridge_break_source.json]
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'tools/lol2'))

PLANKS = [210, 212, 213, 214]
BREAK = {26868: ['c60000003201', 'c590d80b0300', '0510d2000100', '0910d3000300', '0903c5030300', '0903c1030300', '0903c2030300',
                 '0903c4030300', '0903c3030300', '1010d2000100', '1010d2000100'],
         26940: ['1410d200c40180000a14']}
CREAKS = {212: (26956, ['1410d4000b0380000a14']), 213: (26966, ['1410d500090380000a14']), 214: (26976, ['1410d6000d0380000a14'])}
FORM_OF_VALUE = {9: [1], 10: [0, 1]}
PREDICATE_206 = '0005000000'
# Native code pins (code file offset = VA + 0x37000).
CODE = {
    0xD39C3: '8b537d3b537974',  # mov edx,[ebx+7D]; cmp edx,[ebx+79]; je
    0xD39F8: '8a83ab0100000fbec0508b4379508b5028ff92b8000000',  # form byte +1AB, new owner +79, records virtual B8
    0xD3A13: 'e8',  # call ADA30
    0xADAC2: '8a43042c0489df3c08',  # kind5: value = record+4, minus 4, <= 8
    0x5D558: '885e3d',  # op5 virtual: mov [esi+3D], bl (mode byte)
    0x5D566: 'e8',  # call 5A8AC (children of the mode)
    0x5D56B: '88463b',  # mov [esi+3B], al
    0x5A8C8: 'd3e6',  # shl esi, cl (1 << mode)
    0x5A8D0: '8b4a3021f1',  # mov ecx,[edx+30]; and ecx,esi (child mask & bit)
}


def code_checks(exe):
    import capstone
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    for va, hexes in CODE.items():
        raw = exe[va + 0x37000:va + 0x37000 + len(hexes) // 2].hex()
        assert raw == hexes, (hex(va), raw)
    call = lambda va: va + 5 + struct.unpack_from('<i', exe, va + 0x37000 + 1)[0]
    assert call(0xD3A13) == 0xADA30 and call(0x5D566) == 0x5A8AC
    # 5D510 writes no placement flags: its only stores are +3D and +3B.
    body = list(md.disasm(exe[0x5D510 + 0x37000:0x5D5CA + 0x37000], 0x5D510))
    stores = sorted({i.op_str.split(',')[0] for i in body if i.mnemonic == 'mov' and i.op_str.startswith('byte ptr [esi')})
    assert stores == ['byte ptr [esi + 0x3b]', 'byte ptr [esi + 0x3d]'], stores
    assert not any('esi + 0x14], ' in i.op_str and i.mnemonic in ('mov', 'or', 'and') for i in body)
    # The mode-2 box path 5BD90..5BF1C reads template bytes 0x2D/0x2F/0x30 and never the assembly mode bytes.
    box = list(md.disasm(exe[0x5BD90 + 0x37000:0x5BF1D + 0x37000], 0x5BD90))
    assert not any('0x3b]' in i.op_str or '0x3d]' in i.op_str for i in box)
    assert sum('+ 0x2d]' in i.op_str for i in box) >= 3 and any('+ 0x2f]' in i.op_str for i in box)
    return [dict(va=hex(va), hex=hexes) for va, hexes in CODE.items()]


def relocation_check():
    import re_helper_root; re_helper_root.insert('draracle', 'tools')
    from verify_special_pixel_table_binding import fixups
    from lol2_extract_draracle_geometry import u32
    return fixups, u32


def main():
    from verify_actor_item_grants import source_area
    from build_game_atlas import section
    from prepare_jungle_bacatta import predicate
    from prepare_cave_entrance_death import native_checks
    import map_materials as mm
    import export_map_movables as em
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output', type=Path, default=ROOT / 'scripts/lol2/jungle_bridge_break_source.json')
    a = p.parse_args()
    exe = (a.game / 'LOLG.DAT').read_bytes()
    native_checks(exe)  # ADA30 jump table 0x549E8 and its form flags
    code = code_checks(exe)
    fixups, u32 = relocation_check()
    le = 0x39024 + u32(exe, 0x39060)
    first = u32(exe, le + u32(exe, le + 0x40) + 108)
    slot = 0x5484 + 0xB0
    rel = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
    assert rel['target_object'] == 2 and rel['target_offset'] + 0x59024 == 0x5D510, rel
    area, arc, item, raw, owners, streams = source_area('L4_HJ', a.game)
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    assert predicate(table, 206)['raw'] == PREDICATE_206
    cmds = lambda o: [c['raw_hex'] for c in streams[o['stream']][o['group']]]
    rows = sorted((o for o in owners if o['owner_kind'] == 'control' and o['owner'] in PLANKS and o['event'] == 5), key=lambda o: o['archive_offset'])
    got = [(o['owner'], o['value'], o['predicate'], o['stream'], o['group'], cmds(o)) for o in rows]
    expect = [(210, 9, 206, 1, g, c) for g, c in BREAK.items()] + [(n, 10, None, 1, g, c) for n, (g, c) in CREAKS.items()]
    assert got == expect, got
    # Direct command census for these controls; this does not exclude every indirect native producer.
    for stream in streams:
        for commands in stream.values():
            for c in commands:
                b = bytes.fromhex(c['raw_hex'])
                if len(b) >= 4 and b[1] == 0x10 and int.from_bytes(b[2:4], 'little') in PLANKS:
                    assert c['raw_hex'] in sum(BREAK.values(), []) + [x for _, cs in CREAKS.values() for x in cs], c
    _, _, controls = section(raw, 0x18, 0x64, 33)
    def placement(n):
        row = controls[n * 33:(n + 1) * 33]; x, z, heading, h = struct.unpack_from('<hhHh', row)
        return dict(id=n, position=[x, h, -z], heading=heading, flags=struct.unpack_from('<H', row, 8)[0], template=row[32], raw=row.hex())
    mix = arc; entries = mm.parse_mix(mix); ident = mm.identify_entries(mix, entries, area['source']['geometry_key'])
    meta = mix[ident['metadata_entry']['offset']:ident['metadata_entry']['offset'] + ident['metadata_entry']['size']]
    em.require = lambda ok, msg: None if ok else (_ for _ in ()).throw(AssertionError(msg))
    templates = em.load_movable_templates(meta)['templates']
    planks = {}
    for n in PLANKS:
        pl = placement(n); t = bytes.fromhex(templates[pl['template']]['raw_hex'])
        assert pl['template'] == 25 and pl['heading'] == 0 and pl['flags'] & 0x80 and not pl['flags'] & 0x1000, pl
        assert t[45] & 3 == 2, 'plank collision is the mode-2 whole box'
        pl.update(box=dict(width=t[47], depth=t[48], height=t[49]))
        planks[str(n)] = pl
    children = templates[25]['children']
    modes = {str(m): sorted(c['index'] for c in children if c['mask'] & (1 << m)) for m in (0, 1)}
    assert modes['1'] == [49, 50, 51, 52] and set(modes['1']) < set(modes['0']), modes
    piece = placement(211)
    assert piece['template'] == 22 and piece['flags'] & 0x1000, piece
    owner = {o['group']: o['archive_offset'] for o in rows}
    ro = struct.unpack_from('<I', raw, 12)[0]; vo = struct.unpack_from('<I', raw, 4)[0]
    region = raw[ro+3032*44:ro+3033*44]
    vertices = struct.unpack_from('<4H', region, 12)
    floor, ceiling = struct.unpack_from('<2h', region, 20)
    assert (floor, ceiling) == (-90, 175)
    creature_region = dict(id=3032, raw=region.hex(), floor=floor, ceiling=ceiling,
        polygon=[[struct.unpack_from('<i',raw,vo+i*8)[0]/65536,-struct.unpack_from('<i',raw,vo+i*8+4)[0]/65536] for i in vertices])
    out = dict(version=1, area='L4_HJ', source=dict(archive_sha256=area['source']['sha256'], executable_sha256=hashlib.sha256(exe).hexdigest()),
               producer=dict(support_owner='D39C3: new owner +79 gets ADA30(records, player +1AB form); old owner gets AD8E0(kind5, value5, argFF)',
                             assembly_op5='vtable5484+B0 -> 5D510 (relocated); writes mode +3D and child count +3B only',
                             form_of_value={str(k): v for k, v in FORM_OF_VALUE.items()}, code=code),
               predicate206=dict(raw=PREDICATE_206, meaning='owner state == 0'),
               planks=planks, mode_children=modes, piece211=piece, creature_region=creature_region,
               breaks=dict(plank=210, value=9, forms=FORM_OF_VALUE[9], predicate=206,
                           groups=[dict(group=g, archive_offset=owner[g], commands=c) for g, c in BREAK.items()],
                           effects=dict(local50=1, region_bit1=3032, plank_mode=1, plank_state=1, link_assembly=211, link_props=[965, 961, 962, 964, 963], sound=452)),
               creaks={str(n): dict(value=10, forms=FORM_OF_VALUE[10], group=g, archive_offset=owner[g], commands=c, sound=int(c[0][8:12][2:4] + c[0][8:12][0:2], 16))
                       for n, (g, c) in CREAKS.items()},
               delivery_contract='docs/jungle-bridge-break.md; source verification alone does not certify gameplay',
               scope='Bounded source contract; the support classifier is replayed by the port as grounded contact on the plank box top '
                     '(source_control_contact.gd tolerance), not the native vertical solver.')
    a.output.write_text(json.dumps(out, indent=1) + '\n')
    print(f'PASS jungle bridge break: plank210 value9 (beast) g26868/g26940, creaks {sorted(CREAKS)}, mode1 children {modes["1"]}, piece211 absent')


if __name__ == '__main__':
    main()
