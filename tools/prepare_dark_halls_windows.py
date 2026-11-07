#!/usr/bin/env python3
"""Stage the Dark Halls (L7_DH) "Windows opened n/7" puzzle in the domed hall.

Source (verify_actor_item_grants.source_area L7_DH, predicates from the 0xbc table):
  controls 237..251 (template35 "Windows for Final", ring at height 785 around the dome floor 760), event6 g7800..8478:
      op9 self property8, op9 three props property3 (their lit selectors), cf0000000501 (local5 += 1),
      op5 self selector1, op6 event1 on a light prop.
  prop242 (the floating orb, template25 prop_142 over the pit regions 1688..1694 at floor 370):
      event6 g2046 if (local5 > 6) AND (local9 == 0): op14 prop64 timer sub4, local9 = 1, sound 546.
      event8 value546 (that sound finished) g2082: ce0000000001 (shared0 GV_LUTHERS_SOUL += 1), op15 window pairs,
      op13 sub17 on actors 58..75 (the 18 SHADEs of the grid hall), op5 prop242 selector1.
      event6 v3 state 1..19 g2406..2730: op18 moves one SHADE to the orb (the orb draws the grid SHADEs one by one).
      event6 v20 if local7 == 0 g2792: op196 floor of regions 1688..1694 -> 740 (the pit closes).
  control246 event3 value1 g8280 c59085050a00: op197 on exit region 1413 (its broken window opens the way out).
Modern adapter (docs/DEVIATIONS.md): a window opens on a Spark hit or E within reach (native trigger: event6 hit
value 25877); the 7th opening runs the orb end at once (no sound wait): soul +1, the 18 grid SHADEs removed, orb gone,
window 246 broken, the Dark Halls exits open. The lit props (empty selector0, decoded selectors not staged) are drawn
as a glow and a light shaft. The orb's SHADE summoning and the pit floor rise are not hosted.
Usage: prepare_dark_halls_windows.py --game GAME [--project PROJECT]
"""
import argparse, json
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ROOT = Path(__file__).resolve().parents[1]
WINDOWS = list(range(237, 252))
ORB, EXIT_WINDOW, EXIT_REGION = 242, 246, 1413
SHADES = list(range(58, 76))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    _, _, _, raw, owners, streams = source_area('L7_DH', a.game.resolve())
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    def group(o): return [c['raw_hex'] for c in streams[o['stream']][o['group']]]
    def find(kind, owner, event, value=None, pred=None):
        rows = [o for o in owners if o['owner_kind'] == kind and o['owner'] == owner and o['event'] == event
                and (value is None or o['value'] == value) and o['predicate'] == pred]
        assert len(rows) == 1, (kind, owner, event, value, pred, rows)
        return rows[0]
    area = json.loads((a.project / 'assets/lol2/generated/dark_halls/area.json').read_text())
    windows = []
    for control in WINDOWS:
        o = find('control', control, 6)
        cmds = group(o)
        assert cmds[0] == f'0910{control:02x}000800' and cmds[4] == 'cf0000000501' and cmds[5] == f'0510{control:02x}000100', (control, cmds)
        assert all(c.startswith('0903') and c.endswith('0300') for c in cmds[1:4]) and cmds[6].startswith('0603'), (control, cmds)
        faces = [f for f in area['faces'] if f.get('kind') == 'movable' and f['source_index'] == control]
        assert len(faces) == 6 and all(f['template'] == 35 for f in faces), control
        pts = [q for f in faces for q in f['points']]
        def face_area(f):
            (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = f['points'][:3]
            return ((x1 - x0) ** 2 + (z1 - z0) ** 2) ** 0.5 * abs(y2 - y1) + ((x2 - x1) ** 2 + (z2 - z1) ** 2) ** 0.5 * abs(y1 - y0)
        front = max(faces, key=face_area)  # the pane (material 1) is the largest face of the thin window box
        lo = [min(q[i] for q in pts) for i in range(3)]; hi = [max(q[i] for q in pts) for i in range(3)]
        windows.append(dict(control=control, group=o['group'], value=o['value'], commands=cmds,
                            center=[(lo[i] + hi[i]) / 2 for i in range(3)], low=lo, high=hi, front=front['points'],
                            lit_props=[int(c[4:6], 16) | int(c[6:8], 16) << 8 for c in cmds[1:4]]))
    start = find('prop', ORB, 6, 3, 30)
    cond = predicate(table, 30)
    assert cond['op'] == 'AND' and (cond['left']['expression']['op'], cond['left']['expression']['left'], cond['left']['expression']['right']) == ('>', {'local': 5}, {'immediate': 6}), cond
    end = find('prop', ORB, 8, 546)
    end_cmds = group(end)
    assert end_cmds[0] == 'ce0000000001', end_cmds
    shades = sorted(int(c[4:6], 16) for c in end_cmds if c.startswith('0d02') and c.endswith('11000000'))
    assert shades == SHADES, shades
    assert '1403f2002202ff0c1f1f' in group(start), 'orb end no longer waits on sound 546'
    pit = find('prop', ORB, 6, 20, 20)
    pit_regions = sorted(int(c[4:6], 16) | int(c[6:8], 16) << 8 for c in group(pit) if c.startswith('c490'))
    breaker = find('control', EXIT_WINDOW, 3, 1)
    assert group(breaker) == ['c59085050a00'], group(breaker)
    orb = next(x for x in area['props'] if x['record'] == ORB)
    target = cond['left']['expression']['right']['immediate'] + 1
    result = dict(version=1, archive='DAT/L7_DH.MIX', target=target, windows=windows,
                  orb=dict(prop=ORB, position=orb['position'], material=orb['material'], start_group=start['group'],
                           end_group=end['group'], end_commands=end_cmds, soul_delta=1, shades=[str(s) for s in shades]),
                  exit=dict(window=EXIT_WINDOW, group=breaker['group'], region=EXIT_REGION),
                  pit=dict(group=pit['group'], regions=pit_regions, floor=740, hosted=False),
                  scope='Original window controls, counter local5 > 6, orb end group (soul +1, grid SHADEs) and exit window 246; '
                        'Spark/E trigger, immediate orb end, glow/shaft presentation are modern adapters.')
    out = a.project / 'scripts/lol2/dark_halls_windows_source.json'
    out.write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS Dark Halls windows: {len(windows)} windows, target {target}, orb {ORB} end g{end["group"]} soul +1, '
          f'{len(shades)} SHADEs, exit window {EXIT_WINDOW} -> region {EXIT_REGION}, pit {pit_regions} (not hosted)')


if __name__ == '__main__':
    main()
