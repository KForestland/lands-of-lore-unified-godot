#!/usr/bin/env python3
"""Pin the prop83 side chamber's animated ambient props and the prop1362 splash sequencer; stage their index frames.

The chamber (regions 1020..1033/1815..1822) has no item grant, no use record and no reward. Its original visible
animation is not drawn by the port (the recovered prop preview omits animated props):
  props 139-141 template90 (mist, 10 frames) and 142-143 template81 (waterfall, 5 frames), looping;
  props 557-564 template74 (splash, 15 frames): each has one kind6 event20 record running op7 (2,0), op7 (0,0).
prop1362 (template19, region420; already drawn): kind2 timer (flags 0x30: fixed 1 s, running) -> op23 state =
random 0..9 (B5A4C), op9 self property21 (B5448 -> ADDE0 event20); its event20 records at state 1..8 send property21
to props 559/558/557/564/563/561/560/562, which raises their event20 (the splash).
Usage: prepare_cave_side_chamber.py --output scripts/lol2/cave_side_chamber_source.json --asset-dir assets/lol2/generated/cave_side_chamber
"""
import argparse, json, shutil, struct
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ALLMAP = Path('/home/bob/lol2_out/all_maps_20260922/L1_DC')
LOOPING = {139: ('prop_145', 90, 10), 140: ('prop_145', 90, 10), 141: ('prop_145', 90, 10), 142: ('prop_260', 81, 5), 143: ('prop_260', 81, 5)}
SPLASH = [557, 558, 559, 560, 561, 562, 563, 564]
ORDER = {1: 559, 2: 558, 3: 557, 4: 564, 5: 563, 6: 561, 7: 560, 8: 562}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True); p.add_argument('--asset-dir', type=Path, required=True)
    a = p.parse_args(); a.asset_dir.mkdir(parents=True, exist_ok=True)
    area, arc, entry, raw, owners, streams = source_area('L1_DC')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    def rows(n):
        return [dict(kind=r['event'], value=r['value'], group=r['group'], predicate=predicate(table, r['predicate'])['raw'] if r['predicate'] is not None else None,
                     raw=arc[r['archive_offset']:r['archive_offset'] + arc[r['archive_offset']]].hex(), commands=[c['raw_hex'] for c in streams[r['stream']][r['group']]])
                for r in owners if r['owner_kind'] == 'prop' and r['owner'] == n]
    seq = rows(1362)
    timer = next(r for r in seq if r['kind'] == 2)
    b = bytes.fromhex(timer['raw']); assert b[4] == 0x30 and not (b[5] & 1) and b[6] == 1 and struct.unpack_from('<H', b, 8)[0] == 60, timer['raw']
    assert timer['commands'] == ['170352050900', '090352051500'], timer
    events = {r['predicate']: r for r in seq if r['kind'] == 6}
    for state, target in ORDER.items():
        r = events['000500000%d' % state]
        assert bytes.fromhex(r['raw'])[4] == 0x14 and r['commands'] == ['0903%s1500' % struct.pack('<H', target).hex()], (state, r)
    assert len(events) == 8
    for n in SPLASH:
        rs = rows(n); assert len(rs) == 1 and rs[0]['kind'] == 6 and bytes.fromhex(rs[0]['raw'])[4] == 0x14, (n, rs)
        own = struct.pack('<H', n).hex(); assert rs[0]['commands'] == ['0703%s0200' % own, '0703%s0000' % own], (n, rs)
    for n in LOOPING: assert rows(n) == [], n
    exported = {q['record']: q for q in json.loads((ALLMAP / 'props/props.json').read_text())['props']}
    sprites = ALLMAP / 'props/sprites'
    props = {}
    def stage(n, material, frames):
        names = []
        for i in range(frames):
            src = sprites / ('%s_frame_%d_index.png' % (material, i)); assert src.exists(), src
            name = '%s_%d_index.png' % (material, i)
            if not (a.asset_dir / name).exists(): shutil.copyfile(src, a.asset_dir / name)
            names.append(name)
        assert not (sprites / ('%s_frame_%d_index.png' % (material, frames))).exists()
        q = exported[n]
        return dict(position=q['position'], region=q['region'], template=q['template'], material=material, frames=names,
                    left=q['left'], right=q['right'], bottom=q['bottom'], top=q['top'])
    for n, (material, template, frames) in LOOPING.items():
        assert exported[n]['template'] == template and exported[n]['material'] == material and exported[n]['animated']
        props[str(n)] = dict(stage(n, material, frames), mode='loop')
    for n in SPLASH:
        assert exported[n]['template'] == 74 and exported[n]['material'] == 'prop_946' and exported[n]['animated']
        props[str(n)] = dict(stage(n, 'prop_946', 15), mode='splash')
    result = dict(version=1, source=area['source'], props=props, sequencer=dict(prop=1362, period_seconds=1.0, random_states=10, order={str(k): v for k, v in ORDER.items()}),
                  frame_seconds=0.1, rewards='none: no grant, use record or reward exists in the chamber',
                  adapters=['animated props are indexed layer-2 billboards at 10 frames/s (native animation clock not replayed)',
                            'op7 (2,0) then (0,0) is played as one splash from frame0, then held on frame0',
                            'the sequencer draws its random state with a seeded generator; its state is not saved (ambient)'],
                  scope='Direct source records; region-entry op12 audio/op18 and markers 610/614 are not hosted.')
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS cave side chamber: %d looping, %d splash props, sequencer 1 s / 10 states' % (len(LOOPING), len(SPLASH)))


if __name__ == '__main__':
    main()
