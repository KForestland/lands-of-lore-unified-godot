#!/usr/bin/env python3
"""Replay initial behavior14 entry and goal6 helper dispatch, not world scheduling."""
import hashlib
import itertools
import json
from pathlib import Path
from verify_hive_executioner import GAME, EXE_HASH, CreatureReplay, capstone, u32, fixups
from extract_creature_frame_events import load_events

ROOT = Path(__file__).resolve().parents[1]


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes()
    assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    md = capstone.Cs(3, 4)
    md.detail = True
    instructions, code = {}, []
    for start, end in [(0xa3d24, 0xa3db6), (0xa3bb6, 0xa3bc3),
                       (0xa7d4c, 0xa7dc3), (0xa1e44, 0xa1f2a), (0xf2984, 0xf29c7)]:
        raw = exe[start + 0x37000:end + 0x37000]
        instructions.update({i.address: i for i in md.disasm(raw, start)})
        code.append(dict(start=start, end=end, sha256=hashlib.sha256(raw).hexdigest()))
    le = 0x39024 + u32(exe, 0x39060)
    first = u32(exe, le + u32(exe, le + 0x40) + 36)
    dispatch = []
    for goal, target in [(14, 0xa3d24), (6, 0xa3bb6)]:
        slot = 0x4961c + goal * 4
        relocation = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
        assert relocation['target_object'] == 2
        assert relocation['target_offset'] + 0x59024 == target
        dispatch.append(dict(goal=goal, slot=slot, target=target))
    machine = CreatureReplay(instructions, b'')
    actor, stack = 0x400000, 0x410000
    rows = []
    calls_at = {0xa3d5d, 0xa3d72, 0xa3d99, 0xa3dae}
    exits = {0xa24ac, 0xa3db6}
    for b5, b8, selector in itertools.product(range(256), [0, 1, 0x30, 0xff], [0, 7, 0xffffffff]):
        machine.regs.update(ebx=actor, esp=stack)
        for offset, value in [(0xa8, 14), (0xaa, 5), (0xb5, b5), (0xb8, b8)]:
            machine.writemem(actor + offset, 1, value)
        machine.writemem(0x9699d, 1, 1)
        machine.writemem(0x9699f, 1, 1)
        pc, calls = 0xa3d24, []
        while True:
            stop = machine.execute(pc, calls_at | exits)
            if stop in exits:
                break
            args = [machine.readmem(machine.regs['esp'] + n * 4, 4) for n in range(3)]
            if stop in {0xa3d5d, 0xa3d99}:
                assert args == [actor, 0, 0xffffffff]
                calls.append('lookup_action0')
                machine.regs['eax'] = selector
            else:
                assert args == [actor, selector, 0]
                calls.append('start_selector')
                machine.regs['eax'] = 1
            pc = stop + instructions[stop].size
        expected = [] if b5 & 1 else (['lookup_action0'] * 2 if selector == 0xffffffff else ['lookup_action0', 'start_selector'])
        assert calls == expected
        assert machine.readmem(actor + 0xaa, 1) == 9
        assert machine.readmem(actor + 0xa8, 1) == 14
        assert machine.readmem(actor + 0xb5, 1) == b5
        assert machine.readmem(actor + 0xb8, 1) == b8 & 0xcf
        assert machine.readmem(0x9699d, 1) == machine.readmem(0x9699f, 1) == 0
        rows.append(dict(b5=b5, b8=b8, selector=selector, calls=calls))
    machine.regs.update(ebx=actor, esp=stack)
    assert machine.execute(0xa3bb6, {0xa3bbb}) == 0xa3bbb
    assert instructions[0xa3bbb].op_str == '0xa9720'
    assert [machine.readmem(machine.regs['esp'] + n * 4, 4) for n in range(3)] == [actor, 0, 3]
    # Actual constructor mask1 and ordinary mode0, all inclusive RNG results.
    source = load_events(GAME)
    idle_rows = []
    definition, table = 0x420000, 0x430000
    for entity_id in [4, 5]:
        entity = source['entities'][entity_id]
        actions = bytes(v for row in entity['entries_bytes'] for v in row)
        machine.writemem(actor + 0x2c, 4, definition)
        machine.writemem(definition + 0x37, 4, table)
        machine.writemem(definition + 0x2e, 1, len(actions) // 4)
        machine.mem[table:table + len(actions)] = actions
        for sample in range(101):
            machine.writemem(actor + 0xb4, 4, 0)
            machine.writemem(actor + 0xac, 1, 1)
            machine.regs['esp'] = stack
            for n, value in enumerate([actor, 0, 0xffffffff]):
                machine.writemem(stack + 4 + 4*n, 4, value)
            machine.execute(0xa7d4c, 0xa7d87)
            assert [machine.readmem(machine.regs['esp'] + 4*n, 4) for n in range(4)] == [definition, 0, 1, 0xffffffff]
            machine.regs['esp'] -= 4
            machine.writemem(machine.regs['esp'], 4, 0xa7d8c)
            machine.execute(0xa1e44, 0xa1e6a)
            machine.regs['eax'] = sample
            machine.execute(0xa1e6f, 0xa1f29)
            machine.regs['esp'] += 4
            machine.execute(0xa7d8c, 0xa7dc2)
            selector = machine.regs['eax']
            assert selector in [0, 1]
            views = entity['states'][selector]['views']
            assert len(views) == 1 and views[0]['resource_reference'] == 769 and views[0]['flags_byte2'] == 0
            # Base setter changed-selector branch stores the requested selector,
            # without substituting the actor's AA9 action byte. No callback flag.
            machine.regs.update(ebx=actor, esp=stack)
            machine.writemem(stack + 0x10, 4, selector)
            machine.writemem(actor + 0x30, 1, 7)
            machine.writemem(actor + 0x14, 4, 0)
            machine.writemem(actor + 0xaa, 1, 9)
            machine.execute(0xf2984, 0xf29c7)
            assert machine.readmem(actor + 0x30, 1) == selector
            assert machine.readmem(actor + 0xaa, 1) == 9
            assert [machine.readmem(machine.regs['esp'] + n*4, 4) for n in range(2)] == [definition, selector]
            idle_rows.append(dict(definition=entity_id, rng=sample, selector=selector, resource=769))
    report = dict(executable_sha256=EXE_HASH, cases=len(rows), dispatch=dispatch, code=code,
                  idle_cases=idle_rows, source_entry_sha256=source['entry_sha256'],
                  goal6_helper=dict(address=0xa9720, arguments=['actor', 0, 3]),
                  scope='Behavior-entry slices only. Goal14 writes AA9 but looks up action0, clears B8 bits30 and two mode globals; busy blocks lookup. Lookup/setter are supplied boundaries. Goal6 calls A9720(actor,0,3); this does not prove movement, event3, activation, admission cadence or live perception. 202 actual constructor-mask idle lookups across both definitions and RNG0..100 select resource769. Base setter changed-selector/no-callback slice stores that selector independently of AA9; later frame setup and scheduling remain boundaries.', rows=rows)
    (ROOT / 'docs/cave-roach-behavior-entry-checks.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS {len(rows)} initial behavior-entry cases, {len(idle_rows)} idle lookup/setter cases and goal6 helper arguments')


if __name__ == '__main__':
    main()
