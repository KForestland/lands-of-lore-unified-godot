#!/usr/bin/env python3
"""Native evidence for the Jungle harvest records (docs/jungle-harvest.md).

Checks (pinned LOLG.DAT): opcode slots 14/17 resolve through the LE jump table to B59BF (-> B47B4) and B5A76; B5A76
adds the signed command byte to owner +0x25 clamped 0..255; B47B4 sub3 acts only on a stopped record (bit0) and clears
it, sub4 sets bit0 and reloads the counter only when the command's byte5 is nonzero; B8AC4 scales flag0x10 ranges by
[0x223A8] and flag0x80 values by [0x223A8]*60; B8BA0 reloads an expired running record with carry; handler slots 9/98
resolve to 0x967A8/0x9B2A0 and handler9 adds the immediate 5 to [0x2271A]; the ADF34 event9 scanner selects none of
the tree/barrel records (they are kind9 hit filters, matched by AE2C8 instead).
"""
import hashlib, json, struct
from pathlib import Path
from build_game_atlas import parse_mix, section
from audit_game_transition_owners import events
from verify_hive_executioner import GAME, EXE_HASH, CreatureReplay, capstone, u32
from verify_special_pixel_table_binding import fixups

ROOT = Path(__file__).resolve().parents[1]


def code(exe, a, z):
    return exe[a + 0x37000:z + 0x37000]


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes(); assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    le = 0x39024 + u32(exe, 0x39060)
    def slot(table, index, obj):
        first = u32(exe, le + u32(exe, le + 0x40) + obj)
        s = table + index * 4
        rel = fixups(exe, le, first - 1 + s // 4096)[s % 4096]
        assert rel['target_object'] == 2
        return rel['target_offset'] + 0x59024
    ops = {op: slot(0x5c878, op - 1, 36) for op in (14, 16, 17)}
    assert ops == {14: 0xb59bf, 16: 0xb5a3c, 17: 0xb5a76}, ops
    assert code(exe, 0xb59bf, 0xb59c6) == bytes.fromhex('5653e8eeedffff')  # push esi; push ebx; call B47B4
    handlers = {h: slot(0xc860, h, 108) for h in (9, 98)}
    assert handlers == {9: 0x967a8, 98: 0x9b2a0}, handlers
    # op17: al=signed [esi+4]; dl=[ebx+25]; eax+=edx; clamp 0..255; [ebx+25]=al.
    assert code(exe, 0xb5a76, 0xb5a9d) == bytes.fromhex('8a460431d20fbec08a532501d085c07d0231c03dff0000007e05b8ff000000bf01000000884325')
    # B47B4 sub3 (B485C): requires bit0 set, clears it; counter reload (B8AC4) only if command byte5 != 0.
    assert code(exe, 0xb485c, 0xb488b).hex() == '8a4305a8010f94c084c00f8522ffffff8a730580e6fe31c08873058a450585c0740d53e84042000083c40466894308'
    # sub4 tail (B498D): sets bit0; counter reload only if command byte5 != 0.
    assert code(exe, 0xb498d, 0xb49ac).hex() == '8a560580ca0131c08856058a450585c00f84ebfdffff56e81b41000083c404'
    # B8AC4: flag0x20 fixed +6 / random(+7,+6); flag0x10 -> *[0x223A8]; flag0x80 -> +6*[0x223A8]*60; else <<8.
    assert code(exe, 0xb8ac4, 0xb8b22).hex() == ('538b5c24088a4304a820740731c08a4306eb1931c08a43065031c08a43075068d8210200e86fb6060083c40c31d28a5304f6c210'
        '740a660faf05a82302005bc3f6c280741430e4668b15a82302008a43060fafc26bc03c5bc3c1e0085bc3')
    # B8BA0 expiry (B8C27): duration > step -> counter += duration-step (carry), else 0.
    assert code(exe, 0xb8c27, 0xb8c50).hex() == '53e897feffff83c40425ffff000039f076118b0c24668b730829c801c666897308eb0666c743080000'
    # Handler9 (96856): [0x2271A] += 5 (immediate), then 7C528(23819,0,30); no definition read on this path.
    assert code(exe, 0x96856, 0x96873).hex() == '6a1e8b151a2702006a0083c205681938020089151a270200e8b55cfeff'
    # ADF34 over the tree/barrel lists: no event9 selection.
    inv = json.loads((ROOT / 'docs/game-source-inventory.json').read_text()); area = next(a for a in inv['areas'] if a['id'] == 'L4_HJ')
    archive = (GAME / area['source']['file']).read_bytes(); assert hashlib.sha256(archive).hexdigest() == area['source']['sha256']
    entry = next(e for e in parse_mix(archive) if e['key'] == area['source']['geometry_key']); geo = archive[entry['offset']:entry['offset'] + entry['size']]
    _, _, props = section(geo, 0x14, 0x60, 37); _, _, eventblob = section(geo, 0x40, 0x88, 1)
    raw = code(exe, 0xadf34, 0xae034); assert raw[0x2e:0x31] == b'\x80\xfc\x09'
    md = capstone.Cs(3, 4); md.detail = True; ins = {i.address: i for i in md.disasm(raw, 0xadf34)}
    cases = []
    for p in [261, 262, 263, 264, 265, 266, 267, 310, 1464]:
        start = int.from_bytes(props[p * 37 + 12:p * 37 + 14], 'little')
        parsed = list(events(eventblob, start)); last = parsed[-1]; listing = eventblob[start:last[0] + len(last[2]) + 2]
        assert listing[1] in (4, 9)
        for sel, anyflag in [(0, 1), (3, 1), (0, 0), (3, 0)]:
            m = CreatureReplay(ins, b''); m.mem[0x400000:0x400000 + len(listing)] = listing; m.writemem(0x2b514, 4, 0x430000)
            m.regs.update(esp=0x440000); m.writemem(0x440004, 4, 0x400000); m.writemem(0x440008, 4, sel); m.writemem(0x44000c, 4, anyflag)
            cursor, groups = 0xadf34, []
            while True:
                stop = m.execute(cursor, {0xadfe2, 0xae004, 0xae033})
                if stop == 0xae033: break
                if stop == 0xadfe2: m.regs['eax'] = 1; cursor = 0xadfe7
                else: groups.append(m.readmem(m.regs['esp'], 4) - 0x430000); m.regs['eax'] = 0; cursor = 0xae009
            assert groups == [], (p, sel, anyflag, groups)
            cases.append(dict(prop=p, sel=sel, any=anyflag, groups=groups))
    report = dict(executable_sha256=EXE_HASH, opcodes={str(k): hex(v) for k, v in ops.items()}, handlers={str(k): hex(v) for k, v in handlers.items()},
                  event9_cases=len(cases), passed=True)
    (ROOT / 'docs/jungle-harvest-native-checks.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS jungle harvest native: op14/16/17, op17 clamp, timer sub3/sub4/duration/carry, handler9 +5, %d event9 cases select nothing' % len(cases))


if __name__ == '__main__':
    main()
