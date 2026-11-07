#!/usr/bin/env python3
"""Verify Vels fruit's item identity and execute its original use handler (definition84, handler20, 0x9732C).

Executed: the handler, the shared held-item removal routine 77ACC (admission gate 0x223D4, held slot +0x90F,
held count +0x913) and the unlink routine 9B8F0 (returns its argument), plus the in-handler pool choice
(primary pool [0x96918] when the item lies inside it, else the fallback [0x9691C]).
Call boundaries, checked by their arguments only: message E3924, cursor refresh ACA44 (held count 0), pool
release 5F830, status indicator 7C7DC and gesture 7C528.
Finding: event1 always clears player status byte +1B5 (0x22729), turns the indicator off and returns 1. The fruit
is removed only when 77ACC admits removal; otherwise it stays held but the cure still happens.
"""
import hashlib
import json
from pathlib import Path

from verify_player_item_effects import (
    GAME, EXE_HASH, DEFINITIONS_SHA, parse_mix, u32, fixups, load,
    machine, side_call,
)

ROOT = Path(__file__).resolve().parents[1]
ITEM = 0x410000
PLAYER_ITEMS = 0x23348
STATUS = 0x22729
POOL = 0x450000


def definition():
    archive = (GAME / 'GLOBAL.MIX').read_bytes()
    entry = next(e for e in parse_mix(archive) if e['key'] == 3984507021)
    blob = archive[entry['offset']:entry['offset'] + entry['size']]
    assert hashlib.sha256(blob).hexdigest() == DEFINITIONS_SHA
    base, count = u32(blob, 4), u32(blob, 0x34)
    names = base + count * 91 + 4
    names += u32(blob, names - 4) * 16 + 4
    names += u32(blob, names - 4) * 12
    record = blob[base + 84 * 91:base + 85 * 91]
    name = blob[names + 84 * 30:names + 84 * 30 + 24].split(b'\0')[0].decode()
    return name, u32(record, 24), record[0x42]


def args(m, n):
    return [m.readmem(m.regs['esp'] + 4 * i, 4) for i in range(n)]


def case(ins, event, gate, presentation, status, pool, held_count):
    m = machine(ins)
    m.writemem(0x420000, 1, event)
    m.writemem(m.regs['esp'] + 8, 4, 0x420000)
    m.writemem(0x269c4, 1, presentation)
    m.writemem(0x269cc, 4, 0x430000)
    m.writemem(0x43012e, 2, 321)
    m.writemem(0x223d4, 1, gate)
    m.writemem(PLAYER_ITEMS + 0x913, 4, held_count)
    m.writemem(PLAYER_ITEMS + 0x90f, 4, ITEM)
    m.writemem(ITEM, 4, 0x470000)
    m.writemem(0x470000 + 0x37, 4, 84 << 16)
    m.writemem(STATUS, 1, status)
    # Primary pool descriptor: base, ?, count, stride. None / containing the item / not containing it.
    if pool == 'none':
        m.writemem(0x96918, 4, 0)
    else:
        m.writemem(0x96918, 4, POOL)
        m.writemem(POOL, 4, 0x400000 if pool == 'inside' else 0x480000)
        m.writemem(POOL + 8, 4, 0x100)
        m.writemem(POOL + 12, 4, 0x200)
    m.writemem(0x9691c, 4, 0x440000)
    # Independent player globals and the status neighbours: the handler must not touch them.
    sentinels = {0x226c1: 17, 0x2271a: 7, 0x2272a: 0x0b0a09, 0x23ac1: 12345, 0x226a1: 99, 0x22cb6: 98}
    for address, value in sentinels.items():
        m.writemem(address, 4, value)
    calls = []
    stop = m.execute(0x9732c, {0x97340, 0x97367, 0x97376})
    if event != 1:
        assert stop == 0x97340 and m.regs['eax'] == 0
        assert m.readmem(STATUS, 1) == status and m.readmem(PLAYER_ITEMS + 0x90f, 4) == ITEM
    else:
        if not presentation:
            assert stop == 0x97367 and args(m, 5) == [0x23c68, 321, 0, 0, 1]
            calls.append('message')
            stop = m.execute(0x9736c, {0x97376})
        assert stop == 0x97376 and args(m, 2) == [PLAYER_ITEMS, 0]
        # The real removal routine. Its cursor refresh (held count 0) is a checked boundary.
        if gate:
            returned = side_call(m, 0x77acc, 0x77ae3, [PLAYER_ITEMS, 0])
        elif held_count:
            returned = side_call(m, 0x77acc, 0x77b38, [PLAYER_ITEMS, 0])
        else:
            saved = dict(m.regs)
            m.regs.update(esp=0x580000, eax=0, ecx=0, edx=0)
            m.writemem(0x580000, 4, 0); m.writemem(0x580004, 4, PLAYER_ITEMS); m.writemem(0x580008, 4, 0)
            assert m.execute(0x77acc, {0x77b2c}) == 0x77b2c
            assert args(m, 4) == [0x22518, 0xffffffff, 12, 12]
            calls.append('cursor')
            assert m.execute(0x77b31, {0x77b38}) == 0x77b38
            returned = m.regs['eax']; m.regs.update(saved); m.regs['eax'] = returned
        assert returned == (0 if gate else ITEM)
        assert m.readmem(PLAYER_ITEMS + 0x90f, 4) == (ITEM if gate else 0)
        m.regs['eax'] = returned
        stop = m.execute(0x9737b, {0x97385, 0x973e2})
        if returned:
            assert stop == 0x97385 and args(m, 2) == [ITEM, 0]
            # 9B8F0 executed: it returns its argument.
            m.regs['eax'] = side_call(m, 0x9b8f0, 0x9b8f4, [ITEM, 0])
            assert m.regs['eax'] == ITEM
            assert m.execute(0x9738a, {0x973cd}) == 0x973cd
            assert args(m, 2) == [POOL if pool == 'inside' else 0x440000, ITEM]
            calls.append('release_primary' if pool == 'inside' else 'release_fallback')
            stop = m.execute(0x973d2, {0x973e2})
        assert stop == 0x973e2 and args(m, 2) == [0x23819, 0] and m.readmem(STATUS, 1) == 0
        calls.append('indicator_off')
        assert m.execute(0x973e7, {0x973f3}) == 0x973f3 and args(m, 3) == [0x23819, 4, 30]
        calls.append('gesture')
        assert m.execute(0x973f8, {0x97404}) == 0x97404 and m.regs['eax'] == 1
    assert all(m.readmem(a, 4) == v for a, v in sentinels.items()), 'unexpected player write'
    return dict(event=event, removal_gate=gate, presentation_suppressed=bool(presentation), status_before=status,
                primary_pool=pool, held_count=held_count, result=m.regs['eax'],
                consumed=event == 1 and not gate, status_after=m.readmem(STATUS, 1), calls=calls)


def verify():
    exe = (GAME / 'LOLG.DAT').read_bytes()
    assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    name, identity, handler = definition()
    assert (name, handler) == ('82-Vels fruit', 20), (name, handler)
    le = 0x39024 + u32(exe, 0x39060)
    first = u32(exe, le + u32(exe, le + 0x40) + 108)
    slot = 0xc860 + handler * 4
    relocation = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
    assert relocation['target_object'] == 2 and relocation['target_offset'] + 0x59024 == 0x9732c
    ins = {}
    code_hash = load(exe, ins, 0x9732c, 0x97405)
    removal_hash = load(exe, ins, 0x77acc, 0x77b39)
    load(exe, ins, 0x9b8f0, 0x9b8f5)
    cases = []
    for event in (0, 8, 10, 11, 255):
        for status in (0, 0x20, 0x40):
            cases.append(case(ins, event, 0, 1, status, 'none', 1))
    for gate in (0, 1):
        for presentation in (0, 1):
            for status in (0, 0x20, 0x40):
                for pool in ('none', 'inside', 'outside'):
                    for held_count in (1, 0):
                        cases.append(case(ins, 1, gate, presentation, status, pool, held_count))
    use = [c for c in cases if c['event'] == 1]
    assert all(c['result'] == 1 and c['status_after'] == 0 for c in use)
    assert {c['consumed'] for c in use if c['removal_gate']} == {False}
    return dict(definition=84, name=name, identity=identity, handler=handler, handler_address='0x9732c',
                executable_sha256=EXE_HASH, definitions_sha256=DEFINITIONS_SHA,
                handler_sha256=code_hash, removal_sha256=removal_hash, cases=cases,
                conclusion=('Use event1 returns 1, clears status byte +1B5 and turns the status indicator off in every case, '
                            'including no status. It removes the held fruit only when 77ACC admits removal (0x223D4 clear); '
                            'otherwise the fruit stays held. Other events return 0 with no change. No other player write.'),
                executed=['handler 0x9732C..0x97404', 'removal 77ACC', 'unlink 9B8F0', 'pool choice'],
                boundaries=['message E3924', 'cursor refresh ACA44', 'pool release 5F830', 'indicator 7C7DC', 'gesture 7C528'],
                limitation='No live player status model exists in the port, so the cure is recorded but has nothing to clear.')


if __name__ == '__main__':
    report = verify()
    (ROOT / 'docs/vels-fruit-use-source.json').write_text(json.dumps(report, indent=2) + '\n')
    n = len(report['cases']); u = sum(c['event'] == 1 for c in report['cases'])
    print(f"PASS {n} original handler cases ({u} use, {n - u} other events); identity {report['identity']}")
