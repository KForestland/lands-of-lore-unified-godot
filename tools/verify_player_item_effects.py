#!/usr/bin/env python3
"""Bind Champion Stone use admission and the verified +20 timer. Other handlers are identified only."""
import hashlib, json
from pathlib import Path
from verify_hive_executioner import GAME, EXE_HASH, CreatureReplay, capstone, u32, fixups
from build_game_atlas import parse_mix
ROOT = Path(__file__).resolve().parents[1]
DEFINITIONS_SHA = 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'

def extend(timer):
    return (timer & 65535) | ((((timer >> 16) + 3600) & 65535) << 16)

def sub(timer, delta):
    return (timer - delta) & 0xffffffff

def positive(timer):
    return 0 < timer < 0x80000000

def load(exe, ins, start, end):
    raw = exe[start + 0x37000:end + 0x37000]
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    rows = list(md.disasm(raw, start))
    if not rows or rows[-1].address + rows[-1].size != end:
        raise SystemExit(f'incomplete span {start:#x}..{end:#x}')
    ins.update({i.address: i for i in rows})
    return hashlib.sha256(raw).hexdigest()

def machine(ins):
    m = CreatureReplay(ins, b'')
    m.regs.update(eax=0, ebx=0, ecx=0, edx=0, esi=0, edi=0, ebp=0x500100, esp=0x500000)
    return m

def side_call(m, entry, stop, args):
    saved = dict(m.regs)
    stack = 0x580000
    m.regs.update(esp=stack, eax=0, ecx=0, edx=0)
    m.writemem(stack, 4, 0)
    for index, value in enumerate(args):
        m.writemem(stack + 4 + 4 * index, 4, value)
    actual = m.execute(entry, stop)
    if actual != stop:
        raise SystemExit(f'side call stopped at {actual:#x}')
    eax = m.regs['eax']
    m.regs.update(saved)
    m.regs['eax'] = eax
    return eax

def use_case(ins, held, gate, flags, caller_bit, callback=1, present=1):
    m = machine(ins)
    caller = 0x600000
    m.writemem(0x23c57, 4, held)
    m.writemem(0x223d0, 4, gate)
    m.writemem(0x2279a, 4, flags)
    m.writemem(0x269c4, 1, present)
    m.writemem(caller + 0x42d, 1, 1 if caller_bit else 0)
    m.writemem(m.regs['esp'], 4, 0)
    m.writemem(m.regs['esp'] + 4, 4, caller)
    bit24 = ((flags << 7) & 0xffffffff) >> 31
    admitted = held != 0 and gate == 0 and bit24 == 0 and not caller_bit
    if not admitted and present == 0:
        stop = m.execute(0x7e968, 0x7e9fd)
        if stop != 0x7e9fd:
            raise SystemExit(f'presentation site {stop:#x}')
        return {'admitted': False, 'result': None, 'presentation_call': True}
    stop = m.execute(0x7e968, {0x7e9aa, 0x7e9db})
    if not admitted:
        if stop != 0x7e9db:
            raise SystemExit(f'reject missed {stop:#x}')
        stop = m.execute(0x7e9db, 0x7ea0b)
        if stop != 0x7ea0b or m.regs['eax'] != 0:
            raise SystemExit('use reject did not return 0')
        return {'admitted': False, 'result': 0, 'presentation_call': False}
    if stop != 0x7e9aa:
        raise SystemExit(f'memset site {stop:#x}')
    args = [m.readmem(m.regs['esp'] + 4 * i, 4) for i in range(3)]
    if args[1] != 0 or args[2] != 0x19:
        raise SystemExit(f'memset args {args}')
    event = args[0]
    m.mem[event:event + 0x19] = bytes(0x19)
    m.execute(0x7e9af, 0x7e9c5)
    if m.readmem(event, 1) != 1 or m.readmem(event + 1, 4) != 0 or m.readmem(event + 21, 4) != 0:
        raise SystemExit('event 1 was not constructed')
    if m.readmem(m.regs['esp'], 4) != held or m.readmem(m.regs['esp'] + 4, 4) != event:
        raise SystemExit('callback arguments mismatch')
    m.regs['eax'] = callback
    stop = m.execute(0x7e9ca, {0x7e9da, 0x7e9db})
    if callback:
        if stop != 0x7e9da or m.regs['eax'] != 1:
            raise SystemExit('admitted use did not return 1')
        return {'admitted': True, 'result': 1, 'presentation_call': False}
    if stop != 0x7e9db:
        raise SystemExit('zero callback did not reject')
    stop = m.execute(0x7e9db, 0x7ea0b)
    if stop != 0x7ea0b or m.regs['eax'] != 0:
        raise SystemExit('zero callback reject failed')
    return {'admitted': True, 'result': 0, 'presentation_call': False}

def activate(ins, active, gate, timer, stat, flags):
    m = machine(ins)
    item, event = 0x410000, 0x420000
    m.mem[event] = 1
    m.writemem(0x269c4, 1, 1)
    m.writemem(0x223d4, 1, gate)
    m.writemem(0x23348 + 0x913, 4, 1)
    m.writemem(0x23348 + 0x90f, 4, item)
    m.writemem(0x2270e, 1, flags | (0x10 if active else 0))
    m.writemem(0x236e4, 4, stat)
    m.writemem(0x23ac1, 4, timer)
    m.writemem(0x23a6d, 4, 0)
    m.writemem(item + 8, 4, 0)
    stack = m.regs['esp']
    m.writemem(stack, 4, 0)
    m.writemem(stack + 4, 4, item)
    m.writemem(stack + 8, 4, event)
    if m.execute(0x96134, 0x9618f) != 0x9618f:
        raise SystemExit('activation did not reach held-item clear')
    if m.readmem(m.regs['esp'], 4) != 0x23348 or m.readmem(m.regs['esp'] + 4, 4) != 0:
        raise SystemExit('77ACC arguments mismatch')
    returned = side_call(m, 0x77acc, 0x77ae3 if gate else 0x77b38, [0x23348, 0])
    if returned != (0 if gate else item) or m.readmem(0x23c57, 4) != (item if gate else 0):
        raise SystemExit('held-item clear mismatch')
    if not active:
        if m.execute(0x96194, 0x961ac) != 0x961ac:
            raise SystemExit('inactive stone did not insert')
        if [m.readmem(m.regs['esp'] + 4 * i, 4) for i in range(3)] != [returned, 0, 1]:
            raise SystemExit('insert arguments mismatch')
        head = side_call(m, 0x9b994, 0x9b9b0, [returned, 0, 1])
        if head != returned:
            raise SystemExit('empty-list insert result mismatch')
        if m.execute(0x961b1, 0x961cd) != 0x961cd:
            raise SystemExit('recalculation call missing')
        if m.readmem(0x236e4, 4) != (stat + 20) & 0xffffffff or m.readmem(0x23a6d, 4) != head:
            raise SystemExit('activation stat or list head mismatch')
        if m.readmem(m.regs['esp'], 4) != 0x23348:
            raise SystemExit('8A364 argument mismatch')
        m.execute(0x961d2, 0x9625f)
    else:
        stop = m.execute(0x96194, {0x961ed, 0x9625f})
        if returned == 0:
            if stop != 0x9625f:
                raise SystemExit('blocked repeat did not extend')
        else:
            if stop != 0x961ed or m.readmem(m.regs['esp'], 4) != returned:
                raise SystemExit('repeat release call mismatch')
            m.regs['edx'] &= 0xffff0000
            m.execute(0x96240, 0x9625f)
        if m.readmem(0x236e4, 4) != stat & 0xffffffff or m.readmem(0x23a6d, 4) != 0:
            raise SystemExit('repeat activation changed the bonus')
    if m.regs['eax'] != 1 or m.readmem(0x23ac1, 4) != extend(timer) or not m.readmem(0x2270e, 1) & 0x10:
        raise SystemExit('activation result mismatch')
    return {'bonus': 0 if active else 20, 'timer': extend(timer), 'consumed': gate == 0}

def maintain_native(ins, timer, delta, flags):
    m = machine(ins)
    m.writemem(0x23ac1, 4, timer)
    m.writemem(0x22c54, 4, delta)
    m.writemem(0x2270e, 4, flags)
    m.writemem(0x236e4, 4, 20)
    stop = m.execute(0x96260, {0x96150, 0x9627d})
    updated = m.readmem(0x23ac1, 4)
    if updated != sub(timer, delta):
        raise SystemExit('timer subtraction mismatch')
    if positive(updated):
        if stop != 0x96150:
            raise SystemExit('positive timer did not return')
        m.execute(0x96150, 0x96158)
        if m.regs['eax'] != 0 or m.readmem(0x236e4, 4) != 20:
            raise SystemExit('live timer changed the bonus')
        return {'expired': False, 'timer': updated, 'bonus': 20, 'presentation': False}
    if stop != 0x9627d:
        raise SystemExit('expiry branch missed')
    if flags & 8 and not flags & 0x4000000:
        if m.execute(0x9627d, 0x962bd) != 0x962bd:
            raise SystemExit('expiry presentation call missing')
        return {'expired': None, 'timer': updated, 'bonus': 20, 'presentation': True}
    if m.execute(0x9627d, 0x96342) != 0x96342 or m.readmem(0x236e4, 4) != 0:
        raise SystemExit('expiry did not reverse +20')
    if m.readmem(m.regs['esp'], 4) != 0x23348:
        raise SystemExit('expiry recalculation argument mismatch')
    m.execute(0x96347, 0x96364)
    if m.regs['eax'] != 1 or m.readmem(0x2270e, 1) & 0x10:
        raise SystemExit('expiry did not clear the active bit')
    return {'expired': True, 'timer': updated, 'bonus': 0, 'presentation': False}

def ancient_admission(ins, event, gate):
    m = machine(ins)
    slot = 0x420000
    m.mem[slot] = event
    m.writemem(0x23c3f, 1, gate)
    stack = m.regs['esp']
    m.writemem(stack + 8, 4, slot)
    stop = m.execute(0x96504, {0x9651e, 0x96532})
    if event not in (1, 9) or gate > 8:
        if stop != 0x9651e or m.regs['eax'] != 0:
            raise SystemExit('ancient admission reject failed')
        return {'admitted': False}
    if stop != 0x96532 or [m.readmem(m.regs['esp'] + 4 * i, 4) for i in range(2)] != [0x23819, 1]:
        raise SystemExit('ancient callee boundary mismatch')
    return {'admitted': True, 'callee': 0x7c5dc}

def aloe_observation(ins, event, initial):
    m = machine(ins)
    slot = 0x420000
    m.mem[slot] = event
    m.writemem(0x269c4, 1, 1)
    m.writemem(0x223d4, 1, 1)
    m.writemem(0x23348 + 0x913, 4, 1)
    m.writemem(0x23348 + 0x90f, 4, 0x410000)
    m.writemem(0x2271a, 4, initial)
    stack = m.regs['esp']
    m.writemem(stack + 8, 4, slot)
    stop = m.execute(0x967a8, {0x967bc, 0x967f2})
    if event != 1:
        if stop != 0x967bc or m.regs['eax'] != 0:
            raise SystemExit('aloe event reject failed')
        return {'admitted': False}
    if stop != 0x967f2:
        raise SystemExit('aloe did not reach consumption')
    returned = side_call(m, 0x77acc, 0x77ae3, [0x23348, 0])
    if returned != 0 or m.readmem(0x23c57, 4) != 0x410000:
        raise SystemExit('blocked aloe consumption mismatch')
    if m.execute(0x967f7, 0x9686e) != 0x9686e:
        raise SystemExit('aloe effect call missing')
    if m.readmem(0x2271a, 4) != (initial + 5) & 0xffffffff:
        raise SystemExit('aloe +5 write mismatch')
    if [m.readmem(m.regs['esp'] + 4 * i, 4) for i in range(3)] != [0x23819, 0, 0x1e]:
        raise SystemExit('7C528 arguments mismatch')
    return {'admitted': True, 'global_2271a': m.readmem(0x2271a, 4), 'callee': 0x7c528, 'implemented': False}

def main():
    exe = (GAME / 'LOLG.DAT').read_bytes()
    if hashlib.sha256(exe).hexdigest() != EXE_HASH:
        raise SystemExit('executable changed')
    archive = (GAME / 'GLOBAL.MIX').read_bytes()
    entry = next(item for item in parse_mix(archive) if item['key'] == 3984507021)
    blob = archive[entry['offset']:entry['offset'] + entry['size']]
    if hashlib.sha256(blob).hexdigest() != DEFINITIONS_SHA:
        raise SystemExit('definition archive changed')
    base, count = u32(blob, 4), u32(blob, 0x34)
    names_at = base + count * 91 + 4
    names_at = names_at + u32(blob, names_at - 4) * 16 + 4
    names_at = names_at + u32(blob, names_at - 4) * 12
    rows = []
    for index in range(count):
        record = blob[base + index * 91:base + (index + 1) * 91]
        name = blob[names_at + index * 30:names_at + index * 30 + 24].split(b'\0')[0].decode('latin1')
        rows.append({'index': index, 'name': name, 'identity': u32(record, 24), 'handler': record[0x42], 'sha256': hashlib.sha256(record).hexdigest()})
    if count != 170 or sum(row['handler'] == 4 for row in rows) != 1:
        raise SystemExit('handler 4 is not unique to Champion Stone')
    champion = rows[123]
    ancient = rows[68]
    aloe = rows[110]
    if champion['name'] != '121-Champion st' or champion['identity'] != 0xfc627897 or champion['handler'] != 4:
        raise SystemExit('Champion Stone definition mismatch')
    if ancient['name'] != '66-Ancients stn' or ancient['identity'] != 3764690106 or ancient['handler'] != 6:
        raise SystemExit('Ancient Stone definition mismatch')
    if aloe['name'] != '108-Cave aloe' or aloe['identity'] != 3732130108 or aloe['handler'] != 9:
        raise SystemExit('Cave Aloe definition mismatch')
    if rows[109]['handler'] != 9 or rows[127]['handler'] != 6:
        raise SystemExit('shared handler ownership changed')
    le = 0x39024 + u32(exe, 0x39060)
    first = u32(exe, le + u32(exe, le + 0x40) + 108)
    relocations = {}
    for index, target in ((4, 0x96134), (6, 0x96504), (9, 0x967a8)):
        slot = 0xc860 + index * 4
        relocation = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
        if relocation['target_object'] != 2 or relocation['target_offset'] + 0x59024 != target:
            raise SystemExit(f'handler {index} relocation mismatch')
        relocations[index] = relocation
    ins = {}
    spans = {
        'use': load(exe, ins, 0x7e968, 0x7ea0c),
        'handler': load(exe, ins, 0x96134, 0x96365),
        'clear': load(exe, ins, 0x77acc, 0x77b39),
        'insert_empty': load(exe, ins, 0x9b994, 0x9b9b1),
        'ancient': load(exe, ins, 0x96504, 0x96532),
        'aloe': load(exe, ins, 0x967a8, 0x9686e),
    }
    use_rows = []
    for held in (0, 0x410000):
        for gate in (0, 1, 0x80000000):
            for flags in (0, 1 << 23, 1 << 24, 0xffffffff):
                for caller_bit in (False, True):
                    callback = 1
                    admitted = held and gate == 0 and ((flags & 0x01000000) == 0) and not caller_bit
                    if admitted and flags == 0 and not caller_bit:
                        callback = 0
                    row = use_case(ins, held, gate, flags, caller_bit, callback)
                    expect = 0 if (not admitted or callback == 0) else 1
                    if row['result'] != expect:
                        raise SystemExit(f'use result {row}')
                    use_rows.append(row)
    use_case(ins, 0, 0, 0, False, present=0)
    activations = [activate(ins, active, gate, timer, stat, 0x20) for active, gate, timer, stat in (
        (False, 0, 0, 100), (False, 1, 0xffff0007, 0xffffffff), (True, 0, 5, 40), (True, 1, 5, 40))]
    maintains = [maintain_native(ins, timer, delta, flags) for timer, delta, flags in (
        (100, 1, 0x10), (100, 100, 0x10), (10, 11, 0x10), (0x80000000, 0, 0x10),
        (50, 50, 0x04000018), (50, 50, 0x18))]
    if maintains[-1]['presentation'] is not True or maintains[-2]['expired'] is not True:
        raise SystemExit('expiry presentation gate mismatch')
    ancient_rows = [ancient_admission(ins, event, gate) for event in (0, 1, 8, 9) for gate in (8, 9)]
    aloe_rows = [aloe_observation(ins, event, initial) for event in (0, 1, 8) for initial in (10, 0xfffffffe)]
    report = {
        'executable_sha256': EXE_HASH,
        'definitions_sha256': DEFINITIONS_SHA,
        'champion': champion,
        'ancient': ancient,
        'cave_aloe': aloe,
        'shared_handlers': {'6': [row['index'] for row in rows if row['handler'] == 6], '9': [row['index'] for row in rows if row['handler'] == 9]},
        'relocations': {str(index): relocations[index] for index in relocations},
        'span_sha256': spans,
        'use_cases': len(use_rows) + 1,
        'activation_cases': activations,
        'maintain_cases': maintains,
        'ancient_cases': len(ancient_rows),
        'aloe_cases': len(aloe_rows),
        'scope': 'Champion Stone use gates, consumption, +20, high-word +3600 and signed expiry are replayed. 8A364, pool release and presentation bodies are not executed. Ancient Stone stops at callee 7C5DC. Cave Aloe reaches an unidentified +5 global write and callee 7C528; neither effect is implemented. Event 8 cadence and the producer of delta 22C54 are not claimed.',
    }
    (ROOT / 'docs' / 'player-item-effects.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS stone binding: {report["use_cases"]} use cases, {len(activations)} activations, {len(maintains)} timer cases; ancient/aloe effects not implemented')

if __name__ == '__main__':
    main()
