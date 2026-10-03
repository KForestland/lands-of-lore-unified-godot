#!/usr/bin/env python3
"""Replay initial behavior14 entry and goal6 helper dispatch, not world scheduling."""
import hashlib
import itertools
import json
from pathlib import Path
from verify_hive_executioner import GAME, EXE_HASH, CreatureReplay, capstone, u32, fixups

ROOT = Path(__file__).resolve().parents[1]


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes()
    assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    md = capstone.Cs(3, 4)
    md.detail = True
    instructions, code = {}, []
    for start, end in [(0xa3d24, 0xa3db6), (0xa3bb6, 0xa3bc3)]:
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
    report = dict(executable_sha256=EXE_HASH, cases=len(rows), dispatch=dispatch, code=code,
                  goal6_helper=dict(address=0xa9720, arguments=['actor', 0, 3]),
                  scope='Behavior-entry slices only. Goal14 writes AA9 but looks up action0, clears B8 bits30 and two mode globals; busy blocks lookup. Lookup/setter are supplied boundaries. Goal6 calls A9720(actor,0,3); this does not prove movement, event3, activation, admission cadence or live perception. Existing one-second action9 presentation is an adapter, not a native startup proof.', rows=rows)
    (ROOT / 'docs/cave-roach-behavior-entry-checks.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS {len(rows)} initial behavior-entry cases and goal6 helper arguments')


if __name__ == '__main__':
    main()
