#!/usr/bin/env python3
"""Separate serialized actor item identity from executable item-list ownership."""
import hashlib
import json
import struct
from pathlib import Path

from build_game_atlas import parse_mix, section
from prepare_hive_wax import entry, u32
from verify_hive_executioner import GAME, EXE_HASH, CreatureReplay, capstone

ROOT = Path(__file__).resolve().parents[1]


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes()
    assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    definitions = entry('GLOBAL.MIX', 3984507021)
    assert hashlib.sha256(definitions).hexdigest() == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    base, count = u32(definitions, 4), u32(definitions, 0x34)
    states = base + count * 91 + 4
    views = states + u32(definitions, states - 4) * 16 + 4
    names = views + u32(definitions, views - 4) * 12
    catalog = {}
    for index in range(count):
        identity = u32(definitions, base + index * 91 + 24)
        assert identity not in catalog
        catalog[identity] = dict(definition=index, name=definitions[names + index * 30:names + index * 30 + 24].split(b'\0')[0].decode())

    decoder = capstone.Cs(3, 4)
    decoder.detail = True
    spans = [(0xa2127, 0xa2134), (0x9ba88, 0x9baa9)]
    instructions, code = {}, []
    for start, end in spans:
        raw = exe[start + 0x37000:end + 0x37000]
        rows = list(decoder.disasm(raw, start))
        assert rows[-1].address + rows[-1].size == end
        instructions.update({i.address: i for i in rows})
        code.append(dict(start=start, end=end, sha256=hashlib.sha256(raw).hexdigest()))

    inventory = json.loads((ROOT / 'docs/game-actors.json').read_text())
    areas = []
    for area in inventory['areas']:
        if area['id'] not in ['L1_DC', 'L3_DH', 'L4_HJ', 'L5_HC']:
            continue
        archive = (GAME / area['source']['file']).read_bytes()
        assert hashlib.sha256(archive).hexdigest() == area['source']['sha256']
        geometry = next(e for e in parse_mix(archive) if e['key'] == area['source']['geometry_key'])
        raw = archive[geometry['offset']:geometry['offset'] + geometry['size']]
        assert hashlib.sha256(raw).hexdigest() == area['source']['geometry_sha256']
        start, total, placements = section(raw, 0x1c, 0x68, 56)
        actors = []
        for index in range(total):
            record = placements[index * 56:(index + 1) * 56]
            identity = u32(record, 52)
            machine = CreatureReplay(instructions, b'')
            actor, frame = 0x400000, 0x410000
            machine.mem[frame - 0x44:frame - 0x44 + 56] = record
            machine.regs.update(ebx=actor, ebp=frame)
            machine.writemem(actor + 0x78, 4, 0xdeadbeef)
            machine.execute(0xa2127, 0xa2134)
            assert machine.readmem(actor + 0x74, 4) == identity
            assert machine.readmem(actor + 0x78, 4) == 0
            actors.append(dict(actor=index, name=area['actors'][index]['name'],
                placement_archive_offset=geometry['offset'] + start + index * 56,
                identity=identity, identity_hex=f'{identity:08x}', item=catalog.get(identity),
                classification='zero' if identity == 0 else ('global_item' if identity in catalog else 'unresolved_nonzero')))
        areas.append(dict(id=area['id'], source=area['source'], actors=actors))

    # Native lookup consumes an existing linked list; a bare identity creates no item.
    lookup_cases = 0
    for identity in [0, 0x178b0a33, 0x0583f6f3, 0xffffffff]:
        for length in range(4):
            for match in range(-1, length):
                machine = CreatureReplay(instructions, b'')
                stack, nodes, defs = 0x410000, 0x420000, 0x430000
                machine.regs.update(esp=stack)
                machine.writemem(stack + 4, 4, nodes if length else 0)
                machine.writemem(stack + 8, 4, identity)
                for index in range(length):
                    node, definition = nodes + index * 16, defs + index * 32
                    machine.writemem(node, 4, definition)
                    machine.writemem(definition + 24, 4, identity if index == match else identity ^ 1)
                    machine.writemem(node + 8, 4, node + 16 if index + 1 < length else 0)
                machine.execute(0x9ba88, 0x9baa8)
                assert machine.regs['eax'] == (nodes + match * 16 if match >= 0 else 0)
                lookup_cases += 1

    report = dict(passed=True, executable_sha256=EXE_HASH, code=code,
        constructor_cases=sum(len(a['actors']) for a in areas), lookup_cases=lookup_cases, areas=areas,
        finding='Native constructor copies placement+52 into actor+0x74 and initializes actor+0x78 item-list head to zero. Native 9BA88 resolves identity only within an existing supplied linked list; identity alone does not establish possessed loot.',
        static_followups=[
            'A2A38 resolves actor+0x74 against actor+0x78 in the B5bit0x10 branch; event8 dispatch precedes this branch.',
            'A5275..A52B1 drains actor+0x78 in the nonzero B7 mode terminal cleanup; ordinary corpse mode takes A52C6 instead.',
            'A57EF..A583B also uses actor+0x74 in an attack-context player-target branch. Do not label the field solely as a guaranteed death drop.'
        ],
        limits=['Constructor prefix and linked-list lookup executed, not the whole constructor or gameplay.',
                'Initial item-list producers, death/use/drop timing, and item allocation still require evidence.',
                'Unresolved nonzero identities are not classified as valid items, unused data, or corruption.',
                'No gameplay behavior changed; source contracts retain their historical loot field name.'])
    out = ROOT / 'docs/act-one-actor-item-identities.json'
    out.write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS {report["constructor_cases"]} native identity transfers; {lookup_cases} item-list lookups')
    for area in areas:
        counts = {kind: sum(a['classification'] == kind for a in area['actors']) for kind in ['zero', 'global_item', 'unresolved_nonzero']}
        print(area['id'], counts)


if __name__ == '__main__':
    main()
