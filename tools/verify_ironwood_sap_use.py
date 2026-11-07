#!/usr/bin/env python3
"""Verify Ironwod sap's item identity and execute its original use handler.

UI presentation, inventory unlink and pool release are explicit call boundaries.
The shared held-item removal routine is executed independently at that boundary.
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


def verify():
    exe = (GAME / 'LOLG.DAT').read_bytes()
    assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    archive = (GAME / 'GLOBAL.MIX').read_bytes()
    entry = next(e for e in parse_mix(archive) if e['key'] == 3984507021)
    blob = archive[entry['offset']:entry['offset'] + entry['size']]
    assert hashlib.sha256(blob).hexdigest() == DEFINITIONS_SHA
    base, count = u32(blob, 4), u32(blob, 0x34)
    names = base + count * 91 + 4
    names += u32(blob, names - 4) * 16 + 4
    names += u32(blob, names - 4) * 12
    record = blob[base + 111 * 91:base + 112 * 91]
    name = blob[names + 111 * 30:names + 111 * 30 + 24].split(b'\0')[0].decode()
    assert (name, u32(record, 24), record[0x42]) == ('109-Ironwod sap', 1690340112, 98)
    le = 0x39024 + u32(exe, 0x39060)
    first = u32(exe, le + u32(exe, le + 0x40) + 108)
    slot = 0xc860 + 98 * 4
    relocation = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
    assert relocation['target_object'] == 2
    assert relocation['target_offset'] + 0x59024 == 0x9b2a0
    ins = {}
    code_hash = load(exe, ins, 0x9b2a0, 0x9b358)
    load(exe, ins, 0x77acc, 0x77b39)
    cases = []
    for event in (0, 1, 8, 10, 11, 255):
        for gate in (0, 1):
            for presentation in (0, 1):
                m = machine(ins)
                m.writemem(0x420000, 1, event)
                m.writemem(m.regs['esp'] + 8, 4, 0x420000)
                m.writemem(0x269c4, 1, presentation)
                m.writemem(0x269cc, 4, 0x430000)
                m.writemem(0x43012e, 2, 123)
                m.writemem(0x223d4, 1, gate)
                m.writemem(0x23348 + 0x913, 4, 1)
                m.writemem(0x23348 + 0x90f, 4, ITEM)
                # Poison independent player globals to detect unintended effects.
                sentinels = {0x226c1: 17, 0x2271a: 7, 0x22729: 3, 0x23ac1: 12345}
                for address, value in sentinels.items():
                    m.writemem(address, 4, value)
                stop = m.execute(0x9b2a0, {0x9b2b4, 0x9b2db, 0x9b2ea})
                consumed = False
                if event != 1:
                    assert stop == 0x9b2b4 and m.regs['eax'] == 0
                else:
                    if not presentation:
                        assert stop == 0x9b2db
                        assert [m.readmem(m.regs['esp'] + 4*i, 4) for i in range(5)] == [0x23c68, 123, 0, 0, 1]
                        stop = m.execute(0x9b2e0, {0x9b2ea})
                    assert stop == 0x9b2ea
                    returned = side_call(m, 0x77acc, 0x77ae3 if gate else 0x77b38, [0x23348, 0])
                    assert returned == (0 if gate else ITEM)
                    m.regs['eax'] = returned
                    stop = m.execute(0x9b2ef, {0x9b2f9, 0x9b357})
                    if returned:
                        assert stop == 0x9b2f9
                        assert [m.readmem(m.regs['esp'] + 4*i, 4) for i in range(2)] == [ITEM, 0]
                        # Unlink returns the supplied item; null primary pool selects fallback.
                        m.regs['eax'] = ITEM
                        m.writemem(0x96918, 4, 0)
                        m.writemem(0x9691c, 4, 0x440000)
                        assert m.execute(0x9b2fe, {0x9b346}) == 0x9b346
                        assert [m.readmem(m.regs['esp'] + 4*i, 4) for i in range(2)] == [0x440000, ITEM]
                        stop = m.execute(0x9b34b, {0x9b357})
                        consumed = True
                    assert stop == 0x9b357 and m.regs['eax'] == 1
                assert all(m.readmem(a, 4) == v for a, v in sentinels.items())
                cases.append(dict(event=event, removal_gate=gate, presentation_suppressed=bool(presentation), consumed=consumed, result=m.regs['eax']))
    return dict(definition=111, name=name, identity=1690340112, handler=98,
                executable_sha256=EXE_HASH, definitions_sha256=DEFINITIONS_SHA,
                handler_sha256=code_hash, cases=cases,
                conclusion='Use event1 removes the held item when removal is admitted; the handler adds no stat effect.',
                boundaries=['UI presentation', 'item unlink', 'pool release'],
                limitation='No claim about other callers of the item, crafting or world-target interactions.')


if __name__ == '__main__':
    report = verify()
    (ROOT / 'docs/ironwood-sap-use-source.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f"PASS {len(report['cases'])} original handler cases")
