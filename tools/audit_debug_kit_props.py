#!/usr/bin/env python3
"""Audit candidate debug-kit records without claiming exhaustive native unreachability.

Pins the executable, scans known direct-call signatures and verifies L1/L3/L4 kit records.
Replays the relocated 0x65381 switch case19 for all 256 flag bytes: wall flags only.
Indirect callers and original-game reachability remain unproved; no reward is implemented.
"""
import argparse, hashlib, json, struct
from pathlib import Path
from verify_actor_item_grants import source_area
from verify_hive_executioner import GAME, EXE_HASH, CreatureReplay, capstone
from verify_special_pixel_table_binding import fixups
from prepare_museum_key_locks import definitions
from build_game_atlas import u32

ROOT = Path(__file__).resolve().parents[1]
CALLERS = {0x5bad5: 1, 0xb230e: 1, 0xb4315: 2, 0xb433c: 3, 0xb435f: 20, 0xd0847: 14, 0xd0868: 15, 0xd0889: 13, 0xd08c5: 16, 0xd0c22: 6,
           0xd39e6: 5, 0xd4ad1: 6, 0xd4af4: 6, 0xd4b39: 6, 0xd757a: 17, 0xd7746: 18, 0xf6c87: 0}


def wall_case19(exe):
    le = 0x39024 + u32(exe, 0x39060)
    first = u32(exe, le + u32(exe, le + 0x40) + 36)
    # Resolve both the switch's displacement and the case slot through LE fixups.
    def target(slot):
        rel = fixups(exe, le, first - 1 + slot // 4096)[slot % 4096]
        assert rel['target_object'] == 2
        return rel['target_offset'] + 0x59024
    assert target(0x65390 - 0x59024) == 0x65318
    assert target(0xc2f4) == 0x65394 and target(0xc2f4 + 19 * 4) == 0x65500
    raw = exe[0x65500 + 0x37000:0x65518 + 0x37000]
    assert raw.hex() == '8a500580f22088500588d680ce40887005b8010000005bc3'
    md = capstone.Cs(3, 4); md.detail = True
    instructions = {i.address: i for i in md.disasm(raw, 0x65500)}
    assert all(i.mnemonic != 'call' for i in instructions.values())
    machine = CreatureReplay(instructions, b''); obj = 0x400000
    for value in range(256):
        before = bytearray([0xa5] * 16); before[5] = value
        machine.mem[obj:obj + 16] = before
        machine.regs.update(eax=obj, esp=0x410000)
        machine.execute(0x65500, 0x65516)  # Stop before restoring caller registers/return.
        expected = before[:]; expected[5] = (value ^ 0x20) | 0x40
        assert machine.mem[obj:obj + 16] == expected and machine.regs['eax'] == 1
    return dict(cases=256, passed=True, entry='0x65500', code_hex=raw.hex(),
                effect='byte +5 = (old XOR 0x20) OR 0x40; EAX=1; no calls',
                limit='Supplied wall-record pointer and byte; parent dispatch/gameplay reachability not replayed.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/debug-kit-props.json')
    args = parser.parse_args()
    exe = (GAME / 'LOLG.DAT').read_bytes()
    assert hashlib.sha256(exe).hexdigest() == EXE_HASH
    found = sorted(off - 0x37000 for off in range(0x37000, len(exe) - 5)
                   if exe[off] == 0xe8 and (off - 0x37000 + 5 + struct.unpack_from('<i', exe, off + 1)[0]) & 0xffffffff == 0xad8e0)
    assert found == sorted(CALLERS), [hex(x) for x in found]
    # Each constant caller pushes "6A value" immediately before "8B .. 28" and the vtable call; F6C87 pushes eax.
    for c, v in CALLERS.items():
        pre = exe[c + 0x37000 - 24:c + 0x37000]
        if c == 0xf6c87:
            assert exe[0xf6c64 + 0x37000:0xf6c79 + 0x37000].hex() == '2500000200752c81ff74250200752468ff00000050'
            continue
        assert bytes([0x6a, v]) in pre, (hex(c), pre.hex())
    blob, base, n, names = definitions()
    ident = {u32(blob[base + i * 91:base + (i + 1) * 91], 24): names[i] for i in range(n)}
    report = dict(executable_sha256=EXE_HASH, dispatcher='AD8E0', caller_values={hex(k): v for k, v in CALLERS.items()}, props={}, wall_case19=wall_case19(exe), limits=['Direct E8 byte-signature scan and known argument patterns; not a complete control-flow or indirect-call proof.', 'Debug/test-kit purpose is a hypothesis. Source commands are not proof of an earned reward.', 'No original interactive execution or global unreachability claim.'])
    for area_id, prop, group in (('L1_DC', 343, 2774), ('L3_DH', 93, 1498), ('L4_HJ', 1913, 16086)):
        area, arc, entry, raw, owners, streams = source_area(area_id)
        recs = [r for r in owners if r['owner_kind'] == 'prop' and r['owner'] == prop and r['event'] == 5]
        assert len(recs) == 1 and recs[0]['value'] == 19 and recs[0]['group'] == group
        cmds = [c['raw_hex'] for c in streams[recs[0]['stream']][group]]
        items = [ident[u32(bytes.fromhex(c), 4)] for c in cmds if c.startswith('0301')]
        if area_id == 'L3_DH':
            assert len(items) == 12 and recs[0]['predicate'] is None
            assert arc[recs[0]['archive_offset']:recs[0]['archive_offset'] + 6].hex() == '0605da051300'
        tag = struct.pack('<H', prop).hex()
        senders = [c['raw_hex'] for st in streams for cs in st.values() for c in cs if c['raw_hex'].startswith('0903' + tag) and c['raw_hex'][8:10] == '13']
        assert not senders, senders
        report['props'][f'{area_id}:prop{prop}'] = dict(source=area['source'], event_archive_offset=recs[0]['archive_offset'], event_hex=arc[recs[0]['archive_offset']:recs[0]['archive_offset'] + 6].hex(), group=group, commands=cmds, items=items, player_ops=[c for c in cmds if c.startswith('0201')], property19_senders=0,
                                                        classification='producer unestablished; candidate debug/test kit; do not grant as a gameplay reward')
    args.output.write_text(json.dumps(report, indent=1) + '\n')
    print('PASS candidate kit audit: 17 known direct signatures, 3 source kit records (Museum12 commands), case19 wall-byte replay256; indirect producers remain unproved')


if __name__ == '__main__':
    main()
