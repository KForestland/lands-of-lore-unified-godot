#!/usr/bin/env python3
"""Classify the multi-item kind5 value19 props L1_DC prop343 and L4_HJ prop1913 as unreachable debug kits.

Each owns one kind5 record with value 19 whose group grants a whole kit of items (Cave: 16, Jungle: 13) plus player
op2 sub-ops 0x0D/0x0E. Kind5 records are dispatched by AD8E0(list, value). Every direct native caller passes a
constant value in {0,1,2,3,5,6,13,14,15,16,17,18,20} (F6C87 passes the masked touch flag, 0 on that path); none passes
19. No stream command sends op9 property19 to either prop. The groups are therefore not reachable in normal play.
Writes docs/debug-kit-props.json.
"""
import json, struct
from pathlib import Path
from verify_actor_item_grants import source_area
from verify_hive_executioner import GAME
from prepare_museum_key_locks import definitions
from build_game_atlas import u32

ROOT = Path(__file__).resolve().parents[1]
CALLERS = {0x5bad5: 1, 0xb230e: 1, 0xb4315: 2, 0xb433c: 3, 0xb435f: 20, 0xd0847: 14, 0xd0868: 15, 0xd0889: 13, 0xd08c5: 16, 0xd0c22: 6,
           0xd39e6: 5, 0xd4ad1: 6, 0xd4af4: 6, 0xd4b39: 6, 0xd757a: 17, 0xd7746: 18, 0xf6c87: 0}


def main():
    exe = (GAME / 'LOLG.DAT').read_bytes()
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
    report = dict(dispatcher='AD8E0', caller_values={hex(k): v for k, v in CALLERS.items()}, props={})
    for area_id, prop, group in (('L1_DC', 343, 2774), ('L4_HJ', 1913, 16086)):
        area, arc, entry, raw, owners, streams = source_area(area_id)
        recs = [r for r in owners if r['owner_kind'] == 'prop' and r['owner'] == prop and r['event'] == 5]
        assert len(recs) == 1 and recs[0]['value'] == 19 and recs[0]['group'] == group
        cmds = [c['raw_hex'] for c in streams[recs[0]['stream']][group]]
        items = [ident[u32(bytes.fromhex(c), 4)] for c in cmds if c.startswith('0301')]
        tag = struct.pack('<H', prop).hex()
        senders = [c['raw_hex'] for st in streams for cs in st.values() for c in cs if c['raw_hex'].startswith('0903' + tag) and c['raw_hex'][8:10] == '13']
        assert not senders, senders
        report['props'][f'{area_id}:prop{prop}'] = dict(group=group, items=items, player_ops=[c for c in cmds if c.startswith('0201')], property19_senders=0,
                                                        classification='unreachable debug/test kit (no producer of kind5 value19)')
    (ROOT / 'docs/debug-kit-props.json').write_text(json.dumps(report, indent=1) + '\n')
    print('PASS debug kit props: %d AD8E0 callers, none passes 19; prop343 %d items, prop1913 %d items' %
          (len(CALLERS), len(report['props']['L1_DC:prop343']['items']), len(report['props']['L4_HJ:prop1913']['items'])))


if __name__ == '__main__':
    main()
