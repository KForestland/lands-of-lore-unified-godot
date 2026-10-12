#!/usr/bin/env python3
"""Pin explicit actor grants and replay command dispatch / item-list insertion.

Allocation and event admission are separate boundaries, not death-drop proof.
"""
import hashlib
import json
import struct
from pathlib import Path

from audit_game_actor_scripts import groups
from audit_game_transition_owners import collect_owners
from audit_act_one_actor_items import entry
from build_game_atlas import parse_mix, section
from verify_hive_executioner import GAME, EXE_HASH, CreatureReplay, capstone, u32
from verify_special_pixel_table_binding import fixups

ROOT = Path(__file__).resolve().parents[1]


def source_area(area_id):
    inventory = json.loads((ROOT / 'docs/game-source-inventory.json').read_text())
    area = next(a for a in inventory['areas'] if a['id'] == area_id)
    archive = (GAME / area['source']['file']).read_bytes()
    assert hashlib.sha256(archive).hexdigest() == area['source']['sha256']
    item = next(e for e in parse_mix(archive) if e['key'] == area['source']['geometry_key'])
    raw = archive[item['offset']:item['offset'] + item['size']]
    assert hashlib.sha256(raw).hexdigest() == area['source']['geometry_sha256']
    owners, _ = collect_owners(raw, item['offset'], area['counts']['regions'])
    streams = []
    for of, sf in [(0x3c, 0x84), (0x44, 0x8c)]:
        start, _, blob = section(raw, of, sf, 1)
        streams.append({g: [dict(archive_offset=item['offset'] + start + off, raw_hex=b.hex())
                           for off, b in commands] for g, commands in groups(blob)})
    return area, archive, item, raw, owners, streams


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes()
    assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    decoder = capstone.Cs(3, 4)
    decoder.detail = True
    instructions, code = {}, []
    for start, end in [(0xa62f4, 0xa6348), (0xa6a34, 0xa6a4f), (0x9b994, 0x9ba54), (0x95b68, 0x95c23)]:
        raw = exe[start + 0x37000:end + 0x37000]
        rows = list(decoder.disasm(raw, start))
        assert rows[-1].address + rows[-1].size == end
        instructions.update({i.address: i for i in rows})
        code.append(dict(start=start, end=end, sha256=hashlib.sha256(raw).hexdigest()))
    machine = CreatureReplay(instructions, b'')
    put = lambda address, value: machine.writemem(address, 4, value)
    get = lambda address: machine.readmem(address, 4)
    le = 0x39024 + u32(exe, 0x39060)
    objects = le + u32(exe, le + 0x40)
    relocations = []
    for slot, data, expected in [(0x4d2a4, False, 0xa631c), (0x42960, False, 0x9ba07),
                                  (0x58d0 + 0x6c, True, 0xa6a34)]:
        first = u32(exe, objects + (108 if data else 36))
        relocation = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
        target = relocation['target_offset'] + 0x59024
        assert relocation['target_object'] == 2 and target == expected
        put(slot, target)
        relocations.append(dict(slot=slot, target=target, source=relocation))
    definitions = entry('GLOBAL.MIX', 3984507021)
    assert hashlib.sha256(definitions).hexdigest() == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    base, count = u32(definitions, 4), u32(definitions, 0x34)
    states = base + count * 91 + 4
    views = states + u32(definitions, states - 4) * 16 + 4
    names = views + u32(definitions, views - 4) * 12
    identities = {}
    for index in range(count):
        identity = u32(definitions, base + index * 91 + 24)
        identities[identity] = dict(definition=index, name=definitions[names + index * 30:names + index * 30 + 24].split(b'\0')[0].decode())
    source = []
    for area_id, wanted in [('L1_DC', [14504, 14534, 14638]), ('L3_DH', [12578])]:
        area, archive, item, raw, owners, streams = source_area(area_id)
        pred_start, _, predicates = section(raw, 0xbc, 0xb8, 5)
        for group in wanted:
            handlers = [o for o in owners if o['stream'] == 1 and o['group'] == group]
            commands = streams[1][group]
            for command in commands:
                b = bytes.fromhex(command['raw_hex'])
                if b[0] == 3:
                    command['item'] = identities[struct.unpack_from('<I', b, 4)[0]]
                    command['argument_byte8'] = b[8]
            source.append(dict(area=area_id, source=area['source'], group=group, handlers=handlers, commands=commands,
                predicates=[dict(index=o['predicate'], raw_hex=predicates[o['predicate'] * 5:o['predicate'] * 5 + 5].hex(),
                                 archive_offset=item['offset'] + pred_start + o['predicate'] * 5)
                            for o in handlers if o['predicate'] is not None]))
    actor, command_ptr, stack = 0x400000, 0x410000, 0x500000
    dispatch = []
    for identity, argument in [(0x7c5eb1bf, 4), (0xe29a1126, 1), (0x9e689a13, 4)]:
        command = bytes.fromhex('03021400') + struct.pack('<I', identity) + bytes([argument, 0, 0, 0])
        machine.mem[command_ptr:command_ptr + len(command)] = command
        put(stack, 0); put(stack + 4, actor); put(stack + 8, command_ptr)
        machine.regs['esp'] = stack
        machine.execute(0xa62f4, 0xa6334)
        args = [get(machine.regs['esp'] + i * 4) for i in range(4)]
        assert args == [actor, identity, argument, 1]
        dispatch.append(dict(command_hex=command.hex(), arguments=args))
    put(actor + 0x78, 0)
    insertions = []
    for node in [0x420000, 0x420010]:
        put(node, 0x430000); put(node + 4, 4); put(node + 8, 0)
        put(stack, 0); put(stack + 4, actor); put(stack + 8, node); put(stack + 12, 1)
        machine.regs['esp'] = stack
        machine.execute(0xa6a34, 0xa6a44)
        args = [get(machine.regs['esp'] + i * 4) for i in range(3)]
        assert args == [node, get(actor + 0x78), 1]
        # Interpreter lacks CALL/RET: bridge exact x86 return-address stack effect.
        machine.regs['esp'] -= 4
        put(machine.regs['esp'], 0xa6a49)
        stop = machine.execute(0x9b994, {a for a, i in instructions.items() if i.mnemonic == 'ret'})
        assert instructions[stop].mnemonic == 'ret' and get(machine.regs['esp']) == 0xa6a49
        machine.regs['esp'] += 4
        machine.execute(0xa6a49, 0xa6a4f)
        insertions.append(dict(node=node, head=get(actor + 0x78), next=get(node + 8)))
    assert get(actor + 0x78) == 0x420010 and get(0x420018) == 0x420000 and get(0x420008) == 0
    report = dict(passed=True, executable_sha256=EXE_HASH, code=code, relocations=relocations,
        global_items_sha256=hashlib.sha256(definitions).hexdigest(), source_groups=source,
        dispatch_cases=dispatch, insertion_cases=insertions,
        static_allocator_chain='95B68 creates one 12-byte node per call, stores argument byte8 as node byte4, and calls owner virtual6C; creature virtual6C is A6A34, whose executed list insertion writes actor+78. Byte8 is not established as item count.',
        findings=['Museum actor20 event9 group12578 explicitly grants two Drag Blood nodes; no generic death-drop conclusion.',
                  'Captain56 state2/use grants player Short Sword then state3; state3/use grants player Brnt Chain then state4 and prop82 state3.',
                  'Captain56 event11/state5 grants Short Sword to actor56, not directly to the player.'],
        limits=['Allocator chain disassembled and pinned, not executed; allocated nodes/definition pointers supplied.',
                'Actual opcode3 dispatch and list insertion executed; CALL/RET stack effects explicitly bridged.',
                'Event admission, global constructor order, successful allocation, world drop and pickup not executed.',
                'Use this alongside actor-item identity audit; placement+52 alone is not owned inventory.'])
    (ROOT / 'docs/actor-item-grants-checks.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS 3 native grant dispatches; 2 list insertions; 4 source grant groups pinned')


if __name__ == '__main__':
    main()
