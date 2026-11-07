#!/usr/bin/env python3
"""Replay original Bestial Disk handler30 with explicit external-call boundaries."""
import argparse
import hashlib
import json
from pathlib import Path
import re_helper_root
re_helper_root.insert('draracle')
import capstone
from verify_creature_states import CreatureReplay

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--game', type=Path, required=True)
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args()
exe = (args.game / 'LOLG.DAT').read_bytes()
digest = hashlib.sha256(exe).hexdigest()
assert digest == 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
raw = exe[0x97bd0 + 0x37000:0x97c86 + 0x37000]
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
md.detail = True
instructions = {i.address: i for i in md.disasm(raw, 0x97bd0)}
stops = {i.address for i in instructions.values() if i.mnemonic in ('call', 'ret')}


def run(request, guard, status, pool_case):
    machine = CreatureReplay(instructions, b'')
    machine.regs['esp'] = 0x700000
    held = 0 if pool_case == 'no_item' else 0x310000
    released = {'inside': 0x320010, 'below': 0x31ffff,
                'end': 0x320040, 'no_pool': 0x320010}.get(pool_case, 0)
    pool = 0 if pool_case == 'no_pool' else 0x330000
    for address, size, value in [
        (0x700008, 4, 0x300000), (0x300000, 1, request),
        (0x23c46, 1, guard), (0x23abd, 1, status),
        (0x96918, 4, pool), (0x9691c, 4, 0x340000),
        (0x330000, 4, 0x320000), (0x330008, 4, 4), (0x33000c, 4, 16),
    ]:
        machine.writemem(address, size, value)
    calls = []
    pc = 0x97bd0
    while True:
        pc = machine.execute(pc, stops)
        instruction = instructions[pc]
        if instruction.mnemonic == 'ret':
            break
        callee = machine.get(instruction, instruction.operands[0])
        call_args = [machine.readmem(machine.regs['esp'] + n * 4, 4) for n in range(2)]
        expected = {
            0x77acc: [0x23348, 0],
            0x9b8f0: [held, 0],
            0x5f830: [0x330000 if pool_case == 'inside' else 0x340000, released],
            0x8619c: [0x2375d, 5],
        }
        assert call_args == expected[callee], (hex(pc), call_args)
        calls.append({'callee': hex(callee), 'args': call_args})
        machine.regs['eax'] = {0x77acc: held, 0x9b8f0: released,
                               0x5f830: 0, 0x8619c: 0}[callee]
        pc += instruction.size
    admitted = request == 1 and not guard & 128
    assert machine.regs['eax'] == int(admitted)
    assert machine.readmem(0x23abd, 1) == (status | 8 if admitted else status)
    assert machine.readmem(0x23c46, 1) == guard
    assert [c['callee'] for c in calls] == (
        (['0x77acc', '0x8619c'] if not held else
         ['0x77acc', '0x9b8f0', '0x5f830', '0x8619c']) if admitted else [])
    assert machine.regs['esp'] == 0x700000
    return calls


cases = 0
for request in range(256):
    if request != 1:
        run(request, 0, 0x55, 'inside')
        cases += 1
for guard in range(256):
    run(1, guard, 0x55, 'inside')
    cases += 1
examples = []
for pool_case in ('no_item', 'inside', 'below', 'end', 'no_pool'):
    for status in range(256):
        calls = run(1, 0, status, pool_case)
        cases += 1
        if status == 0:
            examples.append({'pool_case': pool_case, 'calls': calls})
# Enter the handler's actual 8619C argument5 path; its downstream call is a boundary.
notify_raw = exe[0x8619c + 0x37000:0x86201 + 0x37000]
notify_ins = {i.address: i for i in md.disasm(notify_raw, 0x8619c)}
notify_cases = []
for entries in ([], [5], [1], [6], [1, 6, 5], [1, 2, 3, 4, 6]):
    machine = CreatureReplay(notify_ins, b'')
    machine.regs['esp'] = 0x700000
    machine.writemem(0x700004, 4, 0x2375d)
    machine.writemem(0x700008, 4, 5)
    machine.writemem(0x2375d + 0x9c, 4, len(entries))
    for index, value in enumerate(entries):
        machine.writemem(0x2375d + 0xa0 + index * 4, 4, value)
    assert machine.execute(0x8619c, 0x861ef) == 0x861ef
    instruction = notify_ins[0x861ef]
    assert machine.get(instruction, instruction.operands[0]) == 0x81820
    assert [machine.readmem(machine.regs['esp'] + n * 4, 4) for n in range(2)] == [0x23819, 0x24]
    machine.regs['eax'] = 0
    assert machine.execute(0x861f4, 0x86200) == 0x86200
    assert machine.regs['eax'] == 1 and machine.regs['esp'] == 0x700000
    notify_cases.append(entries)
args.out.write_text(json.dumps({
    'executable_sha256': digest,
    'handler': 30, 'span': ['0x97bd0', '0x97c86'],
    'code_sha256': hashlib.sha256(raw).hexdigest(), 'cases': cases,
    'examples': examples, 'callee_8619c_cases': notify_cases,
    'callee_8619c_code_sha256': hashlib.sha256(notify_raw).hexdigest(),
    'scope': 'Original handler instructions replayed. External calls 77ACC, 9B8F0, '
             '5F830 and 8619C remain explicit boundaries with supplied returns. '
             'Proves request1 and guard23C46 bit7 admission, pool range selection, '
             'OR8 into23ABD, call8619C(2375D,5), and success even if held item is null. '
             'Does not prove native form effect, status-bit reader, external removal '
             'or spell semantics, earned item use, or a hosted gameplay implementation. '
             'Separately enters8619C argument5 path: calls81820(23819,36) and '
             'returns1 regardless of supplied list membership;81820 is unentered.'
}, indent=2) + '\n')
print('PASS', cases, 'handler30 boundary cases; form effect remains unverified')
