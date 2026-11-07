#!/usr/bin/env python3
"""Stage the vine-clearing oil pool fire (L4_HJ prop1350, longplay 39:44, JUNGLE_GATES.md item 2).

Source (verify_actor_item_grants.source_area L4_HJ, predicates from the 0xbc table):
  prop1350 (template65 rock pile in the oil, sprite prop_866) kind9 value 0x11 (Spark/fire masks) under predicate206
  (owner state 0), group 14784: op2 sub0x0C (player reward), op9 property18 on itself, op9 property3 (link) on the 15
  dormant flame props (template66/67/68, sprite prop_1023) and property19 durability 9 on each, op16 state1, op15,
  op6 sub1 on four flames, op20 sound 411, op208 shake. The flames are never unlinked: once lit they keep burning.
Sprites and frames come from lol2.map_props.export_props (RGBA frames, 10 fps provisional, as every jungle prop).
Modern adapters (docs/DEVIATIONS.md): the hit is the port's Spark ray (spark_receiver); the one-time magic100 reward uses player_property_rewards; sound and shake
are not hosted. State: quests.jungle_oil_fire {"lit": bool}.
Usage: prepare_jungle_oil_fire.py --game GAME [--project PROJECT]
"""
import argparse, json, shutil, tempfile
from pathlib import Path
from verify_actor_item_grants import source_area
from prepare_jungle_exit_encounter import predicate
from build_game_atlas import section

ROOT = Path(__file__).resolve().parents[1]
PILE = 1350
FLAMES = [421, 422, 423, 424, 425, 426, 1315, 1328, 1329, 1351, 1352, 1353, 1354, 1355, 1356]


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    game = a.game.resolve()
    _, _, _, raw, owners, streams = source_area('L4_HJ', game)
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    hits = [o for o in owners if o['owner_kind'] == 'prop' and o['owner'] == PILE]
    assert len(hits) == 1 and hits[0]['event'] == 9 and hits[0]['value'] == 0x11, hits
    cond = predicate(table, hits[0]['predicate'])
    assert (cond['op'], cond['left'], cond['right']) == ('==', {'owner_state': True}, {'immediate': 0}), cond
    commands = [c['raw_hex'] for c in streams[hits[0]['stream']][hits[0]['group']]]
    assert '020100000c01' in commands, 'Expected one-time magic100 command absent'
    linked = sorted(int(c[6:8] + c[4:6], 16) for c in commands if c.startswith('0903') and c.endswith('0300'))
    assert linked == FLAMES, linked
    assert sorted(int(c[6:8] + c[4:6], 16) for c in commands if c.endswith('1309')) == FLAMES
    assert f'1003{PILE & 255:02x}{PILE >> 8:02x}0100' in commands, 'state 1 missing'
    from lol2.map_props import export_props
    out = a.project / 'assets/lol2/generated/jungle_oil_fire'
    with tempfile.TemporaryDirectory(prefix='oil-fire-') as temp:
        t = Path(temp)
        report = export_props(game, 'L4_HJ', t / 'props', material_root=t / 'materials')
        props = {x['record']: x for x in report['props']}
        if out.exists(): shutil.rmtree(out)
        out.mkdir(parents=True)
        def stage(record):
            x = props[record]
            frames = []
            for i, f in enumerate(report['animations'][x['material']]['frames']):
                name = f"{x['material']}_{i}.png"
                if not (out / name).exists(): shutil.copyfile(t / 'props' / f, out / name)
                frames.append('res://assets/lol2/generated/jungle_oil_fire/' + name)
            return dict(prop=record, template=x['template'], position=x['position'], region=x['region'], left=x['left'],
                        right=x['right'], bottom=x['bottom'], top=x['top'], material=x['material'], frames=frames)
        pile = stage(PILE)
        flames = [stage(r) for r in FLAMES]
    assert pile['material'] == 'prop_866' and all(f['material'] == 'prop_1023' for f in flames)
    result = dict(version=1, archive='DAT/L4_HJ.MIX', pile=pile, flames=flames, hit=dict(event=9, value=0x11, predicate=hits[0]['predicate'],
                  group=hits[0]['group'], commands=commands), fps=10,
                  not_hosted=['op20 sound 411', 'op208 screen shake', 'flame durability (property19 = 9)'],
                  scope='Original rock pile and 15 flames with their sprites; Spark hit at state 0 lights them for good.')
    (a.project / 'scripts/lol2/jungle_oil_fire_source.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS jungle oil fire: pile {PILE} at {pile["position"]}, {len(flames)} flames, group {hits[0]["group"]}')


if __name__ == '__main__':
    main()
