#!/usr/bin/env python3
"""Replay object-relative curse-item admission; supplied object binding is explicit."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
import re_helper_root
re_helper_root.insert('draracle')
import capstone
from verify_creature_states import CreatureReplay
from verify_special_pixel_table_binding import fixups

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--game', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
b = (a.game / 'LOLG.DAT').read_bytes()
sha = hashlib.sha256(b).hexdigest()
assert sha == 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
raw = b[0x7c3d8 + 0x37000:0x7c482 + 0x37000]
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
md.detail = True
ins = {i.address: i for i in md.disasm(raw, 0x7c3d8)}
stops = {i.address for i in ins.values() if i.mnemonic == 'ret'}
cases = 0
for status in range(256):
    for form in (0, 1, 2, 255):
        for choice in (0, 1, 2, 3, 4, 5, 0xffffffff):
            for flags in (0, 128, 32768, 32896):
                m = CreatureReplay(ins, b'')
                m.regs['esp'] = 0x700000
                for address, size, value in [
                    (0x700004, 4, 0x23819), (0x700008, 4, choice),
                    (0x23abd, 1, status), (0x2271f, 1, form),
                    (0x23819 + 0x42c, 2, flags),
                ]:
                    m.writemem(address, size, value)
                assert m.execute(0x7c3d8, stops) in stops
                admitted = form != 1 and (
                    (choice == 0 and bool(status & 1)) or
                    (choice == 1 and bool(status & 2) and form != 0) or
                    (choice == 2 and bool(status & 4) and form != 2) or
                    (choice == 3 and bool(status & 8)) or
                    (choice == 4 and bool(flags & 128) and not flags & 32768))
                assert m.regs['eax'] == int(admitted)
                assert m.readmem(0x23abd, 1) == status
                assert m.regs['esp'] == 0x700000
                cases += 1
# Pin one actual call-site instruction span; register-to-object producer is not entered.
caller = b[0x7d77b + 0x37000:0x7d792 + 0x37000]
ci = {i.address: i for i in md.disasm(caller, 0x7d77b)}
assert ci[0x7d786].mnemonic == 'call' and ci[0x7d786].operands[0].imm == 0x7c3d8
assert ci[0x7d790].mnemonic == 'jne' and ci[0x7d790].operands[0].imm == 0x7d7cf
# Original group5 option3 -> effect28 -> dispatch branch, through initialized LE pages.
u32 = lambda offset: struct.unpack_from('<I', b, offset)[0]
le = 0x39024 + u32(0x39060)
objects = le + u32(le + 0x40)
first = u32(objects + 108)
def initialized(offset):
    page = le + u32(le + 0x48) + (first - 1 + offset // 4096) * 4
    assert b[page + 3] == 0
    physical = int.from_bytes(b[page:page + 3], 'big')
    return b[0x39024 + u32(le + 0x80) + (physical - 1) * 4096 + offset % 4096]
assert initialized(0xbb20 + 5 * 2) == 25
index = 25 + 3
assert bytes(initialized(0xb95c + index * 4 + n) for n in range(4)).hex() == '64190001'
dispatch_operand = 0xd24b5 - 0x59024
dispatch = fixups(b, le, 1 + dispatch_operand // 4096)[dispatch_operand % 4096]
assert dispatch['target_object'] == 2 and dispatch['target_offset'] == 0x77e5c
slot = 0x77e5c + index * 4
binding = fixups(b, le, 1 + slot // 4096)[slot % 4096]
assert binding['target_object'] == 2 and binding['target_offset'] + 0x59024 == 0xd1f59
branch_raw = b[0xd1e8c + 0x37000:0xd1fb6 + 0x37000]
branch_ins = {i.address: i for i in md.disasm(branch_raw, 0xd1e8c)}
branch_stops = {i.address for i in branch_ins.values() if i.mnemonic == 'call'} | {0xd1134}
branch_cases = []
for form in (0, 1, 2, 255):
    for flag in (0, 16):
        m = CreatureReplay(branch_ins, b'')
        m.regs.update(esp=0x700000, ebp=0x710000, ebx=0x22574)
        m.writemem(0x2271f, 1, form)
        m.writemem(0x22574 + 0x228, 1, flag)
        pc = 0xd1f59
        calls = []
        while True:
            pc = m.execute(pc, branch_stops)
            if pc == 0xd1134:
                break
            i = branch_ins[pc]
            callee = m.get(i, i.operands[0])
            count = 3 if callee in (0x7c528, 0xd6b20) else 2
            values = [m.readmem(m.regs['esp'] + n * 4, 4) for n in range(count)]
            calls.append([hex(callee), values])
            m.regs['eax'] = 0
            pc += i.size
        expected = ([['0x7c528', [0x23819, 3, 30]], ['0x7fe0c', [0x23819, 1]],
                     ['0xd6b20', [0x22574, 1, 60]]] if form == 0 and flag & 16 else
                    [['0x7ff34', [0x23819, 1]], ['0x80064', [0x23819, 1]],
                     ['0x7c528', [0x23819, 3, 30]]])
        assert calls == expected
        assert m.readmem(0x2271f, 1) == form and m.regs['esp'] == 0x700000
        branch_cases.append({'form_byte': form, 'flag228': flag, 'calls': calls})
a.out.write_text(json.dumps({
    'executable_sha256': sha, 'code_sha256': hashlib.sha256(raw).hexdigest(),
    'span': ['0x7c3d8', '0x7c482'], 'cases': cases,
    'caller_span': ['0x7d77b', '0x7d792'],
    'caller_sha256': hashlib.sha256(caller).hexdigest(),
    'dispatch_relocation': dispatch, 'option3_binding': binding,
    'branch_sha256': hashlib.sha256(branch_raw).hexdigest(), 'branch_cases': branch_cases,
    'scope': 'Actual predicate instructions replayed with supplied object23819, '
             'which makes offset2A4 alias23ABD. Choice3 needs status bit8 and '
             'global2271F !=1; no bit is consumed. Choice0/1/2 and special4 '
             'are checked separately. Caller7D786 forwards EBX/EDI when '
             'object400==5; object-register producer, form-name mapping, '
             'input dispatch and actual form change remain unentered. '
             'Original group5 map25 plus option3 is effect28, LE dispatch ->D1F59. '
             'Branch replay with player22574 callsD6B20(player,1,60) only when '
             'form byte0 and player228 bit4 set; other inputs take refusal calls. '
             'All branch callees remain explicit external boundaries. '
             'This is a source boundary experiment, not earned gameplay.'
}, indent=2) + '\n')
print('PASS', cases, 'object-relative predicate cases; live caller binding remains open')
