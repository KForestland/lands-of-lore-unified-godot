#!/usr/bin/env python3
"""Pin the Hive corridor support pillars 401/426/676/725 and their kind9 hit records (docs/hive-reaver-pillars.md).

Each pillar (template1/5, material prop_59, region366, floor -235) owns five kind9 (hit) records in L5_HC stream1:
  value2048 state==0: op208 shake(2,2), op20 sound 0x3BB, op16 self state1
  value2048 state==1: op208 shake(3,3), op20 sound 0x3BC, op16 self state2
  value2048 state==2: op208 shake(3,2), op20 sound 0x2B9
  value2048 always:   op20 sound 0x2BA, op196 region365 floor -> -234 speed20 (the Reaver timer's nudge, speed5)
  value0 always:      op20 sound 0x3BC
The op196 nudge raises region365's floor start event, i.e. the existing collapse chain (hive_reaver_amber_state.gd).
Writes scripts/lol2/hive_reaver_pillars_source.json (numbers only) and stages the original first frame as
assets/lol2/generated/hive_reaver_amber/pillar.png (local, from the user's game files; never published).
"""
import hashlib, json, shutil, struct
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ROOT = Path(__file__).resolve().parents[1]
ALLMAP = Path('/home/bob/lol2_out/all_maps_20260922/L5_HC')
PILLARS = [401, 426, 676, 725]
TRIGGER = dict(region=365, surface='floor', target=-234, speed=20)


def main():
    area, arc, entry, raw, owners, streams = source_area('L5_HC')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    review = json.loads((ALLMAP / 'review.json').read_text())

    def find(o):
        if isinstance(o, dict):
            if o.get('record') in PILLARS and 'placement_hex' in o: yield o
            for v in o.values(): yield from find(v)
        elif isinstance(o, list):
            for v in o: yield from find(v)
    placed = {p['record']: p for p in find(review)}
    out = {}
    for n in PILLARS:
        p = placed[n]
        assert arc[p['placement_offset']:p['placement_offset'] + len(p['placement_hex']) // 2].hex() == p['placement_hex'], n
        assert p['material'] == 'prop_59' and p['region'] == 366 and p['template'] in (1, 5) and p['position'][1] == -235
        rows = [r for r in owners if r['owner_kind'] == 'prop' and r['owner'] == n]
        assert len(rows) == 5 and all(r['event'] == 9 for r in rows), n
        records = []
        for r in rows:
            cmds = [c['raw_hex'] for c in streams[r['stream']][r['group']]]
            pred = predicate(table, r['predicate'])['raw'] if r['predicate'] is not None else None
            records.append(dict(value=r['value'], group=r['group'], predicate=pred, commands=cmds))
        by = {(x['value'], x['predicate']): x['commands'] for x in records}
        sid = struct.pack('<H', n).hex()
        assert by[(2048, '0005000000')] == ['d090000000020200', '1403' + sid + 'bb03c8000a14', '1003' + sid + '0100'], n
        assert by[(2048, '0005000001')] == ['d090000000030300', '1403' + sid + 'bc03c8000a14', '1003' + sid + '0200'], n
        assert by[(2048, '0005000002')] == ['d090000000030200', '1403' + sid + 'b902fa000a14'], n
        assert by[(2048, None)] == ['14030d01ba02ff101f1f', 'c4906d0116ff001400000000'], n
        assert by[(0, None)] == ['1403' + sid + 'bc0364000a14'], n
        b = bytes.fromhex(by[(2048, None)][1]); region, target = struct.unpack_from('<Hh', b, 2)
        assert (region, target, b[6] & 1, b[7]) == (TRIGGER['region'], TRIGGER['target'], 0, TRIGGER['speed'])
        out[str(n)] = dict(template=p['template'], position=p['position'], region=p['region'], left=p['left'], right=p['right'],
                           bottom=p['bottom'], top=p['top'], frame_flags=p.get('frame_flags', 0), placement_offset=p['placement_offset'],
                           placement_hex=p['placement_hex'], records=records)
    frame = ALLMAP / 'props/sprites/prop_59_frame_0.png'
    dest = ROOT / 'assets/lol2/generated/hive_reaver_amber'; dest.mkdir(parents=True, exist_ok=True)
    shutil.copy2(frame, dest / 'pillar.png')
    result = dict(version=1, source=area['source'], pillars=out,
                  states={'0': dict(next=1, shake=[2, 2]), '1': dict(next=2, shake=[3, 3]), '2': dict(next=2, shake=[3, 2])},
                  trigger=TRIGGER, image=dict(file='pillar.png', sha256=hashlib.sha256(frame.read_bytes()).hexdigest()),
                  scope='kind9 value2048 records run on every landed player hit (adapter; native hit-mask filter not traced). '
                        'Hosted: per-pillar state 0->1->2 and the region365 floor nudge. Not hosted: op208 shakes, op20 sounds, '
                        'the value0 (depleted) record; first original frame only, static.')
    (ROOT / 'scripts/lol2/hive_reaver_pillars_source.json').write_text(json.dumps(result, indent=1) + '\n')
    print('PASS hive reaver pillars: 4 placements + 20 kind9 records pinned, region365 floor nudge -234 speed20, frame staged')


if __name__ == '__main__':
    main()
