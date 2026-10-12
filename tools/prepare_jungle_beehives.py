#!/usr/bin/env python3
"""Pin Jungle beehives props251-253 (template56) and export their three selector images.

Each hive has the same source records (owner state = fullness 0 full, 1 half, 2 empty):
  kind4 mode0 (empty hand) state0: selector1/state1, op14 op3 starts kind2 record0, op3 player "71-Wax" (identity
      0xAE5ADACF, property4: one item); state1: selector2/state2, starts kind2 records 0 and 1, op3 one more Wax;
      state2: op15 sub108 on the player (DD104 sets player status +0x225=0x27 and plays a sound; not hosted).
  kind2 (timer) records with flags 0x10 and range bytes 244..250: state1 -> state0/selector0, state2 -> state1/selector1.
  kind5 value2 (hit): selector2/state2, op15 sub108, starts both timers (not hosted).
Usage: prepare_jungle_beehives.py --output scripts/lol2/jungle_beehives_source.json --asset-dir assets/lol2/generated/jungle_beehives
"""
import argparse, hashlib, json, shutil, struct
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate
from lol2 import map_props as props
from build_game_atlas import parse_mix

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('/home/bob/lol2_out/all_maps_20260922/L4_HJ')
HIVES = [251, 252, 253]
WAX = dict(identity=0xAE5ADACF, name='71-Wax')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True); p.add_argument('--asset-dir', type=Path, required=True)
    a = p.parse_args()
    area, arc, entry, raw, owners, streams = source_area('L4_HJ')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    grant = '03010000' + struct.pack('<I', WAX['identity']).hex() + '04000000'
    hives = {}
    for n in HIVES:
        rows = [r for r in owners if r['owner_kind'] == 'prop' and r['owner'] == n]
        recs = []
        for r in rows:
            cmds = [c['raw_hex'] for c in streams[r['stream']][r['group']]]
            recs.append(dict(kind=r['event'], value=r['value'], group=r['group'], predicate=r['predicate'],
                             predicate_expression=predicate(table, r['predicate']) if r['predicate'] is not None else None, commands=cmds,
                             raw=arc[r['archive_offset']:r['archive_offset'] + arc[r['archive_offset']]].hex()))
        use = {r['predicate_expression']['raw']: r for r in recs if r['kind'] == 4}
        timers = {r['predicate_expression']['raw']: r for r in recs if r['kind'] == 2}
        hit = [r for r in recs if r['kind'] == 5]
        own = n.to_bytes(2, 'little').hex()
        sel = lambda v: '0503%s%02x00' % (own, v); st = lambda v: '1003%s%02x00' % (own, v)
        assert set(use) == {'0005000000', '0005000001', '0005000002'} and set(timers) == {'0005000001', '0005000002'} and len(hit) == 1, n
        u0, u1, u2 = use['0005000000']['commands'], use['0005000001']['commands'], use['0005000002']['commands']
        assert grant in u0 and sel(1) in u0 and st(1) in u0 and '0e03%s03000000' % own in u0
        assert grant in u1 and sel(2) in u1 and st(2) in u1 and '0e03%s03000100' % own in u1
        assert u2 == ['0f03%s6c010000' % own]
        t1, t2 = timers['0005000001'], timers['0005000002']
        assert st(0) in t1['commands'] and sel(0) in t1['commands'] and st(1) in t2['commands'] and sel(1) in t2['commands']
        for t in (t1, t2):
            b = bytes.fromhex(t['raw']); assert b[4] == 0x10 and (b[6], b[7]) in ((0xf4, 0xfa),), t['raw']
        assert '0f03%s6c010000' % own in hit[0]['commands'] and hit[0]['value'] == 2
        hives[str(n)] = dict(records=recs, timer_range=[244, 250])
    # Placement and selector art (template56).
    exported = {q['record']: q for q in json.loads((MAP / 'props/props.json').read_text())['props']}
    meta = next(e for e in parse_mix(arc) if e['key'] == 3710142494)
    templates = props.load_templates(arc[meta['offset']:meta['offset'] + meta['size']])['templates']
    tex = (MAP / 'materials/texture.bin').read_bytes()
    report = json.loads((MAP / 'materials/materials.json').read_text())
    assert hashlib.sha256(tex).hexdigest() == report['source_hash']['decoded_texture_sha256']
    sec = props.mm.sections(tex); rgb = props.mm.rgb_palette(tex[props.u32(tex, 4):][:768], 6)
    tmp = a.asset_dir / '_build'; (tmp / 'sprites').mkdir(parents=True, exist_ok=True)
    selectors = []
    for s in templates[56]['selectors']:
        frame = s['frames'][0]
        image = props.build_image(frame['descriptor'], tex, sec, rgb, tmp / 'sprites', tmp, {})
        src = tmp / (image.get('frames', [image['image']])[0]); name = 'hive_%d.png' % s['selector']
        shutil.copyfile(src, a.asset_dir / name)
        selectors.append(dict(selector=s['selector'], descriptor=frame['descriptor'], image=name, left=frame['left'], right=frame['right'],
                              bottom=frame['bottom'], top=s['state_height'] - frame['top_trim'], sha256=hashlib.sha256((a.asset_dir / name).read_bytes()).hexdigest()))
    shutil.rmtree(tmp)
    assert [s['selector'] for s in selectors][:3] == [0, 1, 2], selectors
    for n in HIVES:
        q = exported[n]; assert q['template'] == 56 and q['selector'] == 0
        hives[str(n)].update(position=q['position'], region=q['region'])
    shutil.copyfile(ROOT / 'assets/lol2/generated/jungle_world_items/item50_wax.png', a.asset_dir / 'wax.png')
    result = dict(version=1, source=area['source'], wax=WAX, hives=hives, selectors=selectors[:3], wax_icon='wax.png',
                  timer_adapter_seconds=247.0,
                  not_hosted=['state2 empty-hand op15 sub108 (B6AB5 -> DD104 player status 0x27 + sound): gameplay effect unestablished',
                              'kind5 value2 hit record (forces empty state, op15 sub108, starts both timers)', 'op20 sounds'],
                  scope='Direct source records. Aim/E, fixed 247 s regrow per stage (source range 244..250 timer units with flag 0x10; unit rate unproved) and the six-item Wax pool are modern adapters.')
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS jungle beehives: %d hives, selectors %s' % (len(hives), [s['image'] for s in selectors[:3]]))


if __name__ == '__main__':
    main()
