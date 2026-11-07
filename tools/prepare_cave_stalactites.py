#!/usr/bin/env python3
"""Pin the L1_DC template72 dripping stalactites (props 359/632/633/634) and prop83's later selector art.

Template72 has five selectors (descriptors 862/872/882/887/897); the four placements start at selector0 with
placement durability byte30 = 10. Each owns, in record order:
  kind9 at owner state0: masks 0x0907/0x0000, threshold9, mode4 -> op5 self selector1, op16 state1, op20 sound 718.
  kind9 at owner state1: masks 0x0907/0x0000, threshold5, mode4 -> op5 self selector2, op16 state3, op20 sound 718.
  kind9 local10==0: masks 0x0906/0x0004, threshold9, mode4 -> local10=1, player op2 sub7 arg10 (D8A1C fighting 10), op20 221.
  kind9 local10==0: masks 0x0001/0x0001, threshold9, mode4 -> local10=1, player op2 sub8 arg10 (D8B94 magic 10), op20 221.
  kind3 selector0/2 reached -> op9 property16 (B5401->E416C: stop the owner's sounds); selector1 reached -> op20 759.
  kind4 mode0 (empty hand) while its own local is 0 -> local=1, op20 298.
Prop359 repeats its state0 record once more at the end (same bytes); the hit scanner AE2C8 runs only the first match.
Template92 (prop83) selectors 0/1/2 are descriptors 19/882/897: prop83's g146 op5 selector2 shows descriptor897.
Usage: prepare_cave_stalactites.py --output scripts/lol2/cave_stalactites_source.json
"""
import argparse, hashlib, json, shutil, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('~/lol2_out/all_maps_20260922/L1_DC')
PROPS = {359: 21, 632: 28, 633: 27, 634: 22}  # prop -> its kind4 local
SOUNDS = [221, 298, 718, 759]
DESCRIPTORS = [862, 872, 882, 887, 897]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    sys.path.insert(0, str(Path(__file__).resolve().parent / 'lol2'))
    from map_props import load_templates
    from lol2_source_format import parse_mix
    area, arc, entry, raw, owners, streams = source_area('L1_DC')
    meta = next(arc[e['offset']:e['offset'] + e['size']] for e in parse_mix(arc) if e['key'] == 2971019266)
    templates = load_templates(meta)['templates']
    t72, t92 = templates[72], templates[92]
    assert [s['frames'][0]['descriptor'] for s in t72['selectors']] == DESCRIPTORS
    assert [s['frames'][0]['descriptor'] for s in t92['selectors']] == [19, 882, 897]
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    exported = {q['record']: q for q in json.loads((MAP / 'props/props.json').read_text())['props']}
    review = json.loads((MAP / 'review.json').read_text())
    props = {}
    for prop, local in PROPS.items():
        q = exported[prop]; placement = bytes.fromhex(q['placement_hex'])
        assert q['template'] == 72 and placement[30] == 10 and placement[35] == 0, prop
        rows = []
        for o in owners:
            if o['owner_kind'] != 'prop' or o['owner'] != prop: continue
            rows.append(dict(group=o['group'], kind=o['event'],
                             raw=arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]].hex(),
                             predicate=predicate(table, o['predicate']) if o['predicate'] is not None else None,
                             commands=[c['raw_hex'] for c in streams[o['stream']][o['group']]]))
        oid = struct.pack('<H', prop).hex()
        hits = [r for r in rows if r['kind'] == 9]
        expected = [('0907', '0000', 9, 'owner==0', ['0503%s0100' % oid, '1003%s0100' % oid, '1403%sce0280000a14' % oid]),
                    ('0907', '0000', 5, 'owner==1', ['0503%s0200' % oid, '1003%s0300' % oid, '1403%sce0280000a14' % oid]),
                    ('0906', '0004', 9, 'local10==0', ['c60000000a01', '02010000070a', '1403%sdd00fffdfa00' % oid]),
                    ('0001', '0001', 9, 'local10==0', ['c60000000a01', '02010000080a', '1403%sdd00fffdfa00' % oid])]
        for r, (m0, m2, threshold, pred, commands) in zip(hits, expected):
            b = bytes.fromhex(r['raw'])
            assert b[4:6].hex() == m0[2:] + m0[:2] and b[6:8].hex() == m2[2:] + m2[:2] and b[8] == threshold and b[9] == 4, (prop, r)
            e = r['predicate']['expression'] if 'expression' in r['predicate'] else r['predicate']
            want = dict(op='==', left={'owner_state': True}, right={'immediate': int(pred[-1])}) if pred.startswith('owner') else dict(op='==', left={'local': 10}, right={'immediate': 0})
            assert {k: r['predicate'][k] for k in ('op', 'left', 'right')} == want, (prop, r['predicate'])
            assert r['commands'] == commands, (prop, r['commands'])
        assert len(hits) == (5 if prop == 359 else 4) and (prop != 359 or hits[4]['raw'][8:] == hits[0]['raw'][8:] and hits[4]['commands'] == hits[0]['commands'])
        k3 = {r['raw'][8:10]: r['commands'] for r in rows if r['kind'] == 3}
        assert k3 == {'00': ['0903%s1000' % oid], '01': ['1403%sf70250020a14' % oid], '02': ['0903%s1000' % oid]}, (prop, k3)
        use = [r for r in rows if r['kind'] == 4]
        assert len(use) == 1 and use[0]['predicate']['left'] == {'local': local} and use[0]['raw'][8:10] == '00', prop
        assert use[0]['commands'][0] == 'c6000000%02x01' % local and use[0]['commands'][1].startswith('1403%s2a01' % oid), use[0]
        props[str(prop)] = dict(position=[q['position'][0], q['position'][1], q['position'][2]], region=q['region'],
                                durability=placement[30], use_local=local, records=rows)
    out = ROOT / 'assets/lol2/generated/cave_stalactites'
    if out.exists(): sys.exit('refusing to overwrite ' + str(out))
    out.mkdir(parents=True)
    selectors = []
    for s in t72['selectors']:
        d = s['frames'][0]['descriptor']; anim = review['animations'][f'prop_{d}']['frames']
        names = []
        for i, f in enumerate(anim):
            src = MAP / f.replace('.png', '_index.png'); name = f'{d}_{i}_index.png'
            shutil.copyfile(src, out / name); names.append(name)
        f0 = s['frames'][0]
        selectors.append(dict(selector=s['selector'], descriptor=d, frames=names, left=f0['left'], right=f0['right'],
                              bottom=f0['bottom'], top=s['state_height'] - f0['top_trim'], state_hex=s['state_hex']))
    # Prop473 (template0, animated prop_268 rock column in region1039): removed by prop83's g146 op9 property2; the
    # recovered prop pack omits animated props, so its four frames are staged here for the prop83 owner.
    q473 = exported[473]; t0 = templates[0]['selectors'][0]['frames'][0]
    assert q473['template'] == 0 and q473['material'] == 'prop_268' and t0['descriptor'] == 268 and q473['animated']
    pillar_frames = []
    for i, f in enumerate(review['animations']['prop_268']['frames']):
        name = f'prop473_{i}_index.png'; shutil.copyfile(MAP / f.replace('.png', '_index.png'), out / name); pillar_frames.append(name)
    assert len(pillar_frames) == 4
    pillar = dict(prop=473, position=q473['position'], region=q473['region'], frames=pillar_frames,
                  left=q473['left'], right=q473['right'], bottom=q473['bottom'], top=q473['top'])
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_creature_audio_clips import stage_clips
    stage_clips(ROOT, 'cave_stalactites', SOUNDS)
    import wave
    sounds = {}
    for r in SOUNDS:
        with wave.open(str(out / f'{r}.wav')) as w: sounds[str(r)] = dict(file=f'{r}.wav', seconds=round(w.getnframes() / w.getframerate(), 4))
    files = {n.name: hashlib.sha256(n.read_bytes()).hexdigest() for n in sorted(out.iterdir())}
    result = dict(version=1, source=dict(area='L1_DC', archive_sha256=hashlib.sha256(arc).hexdigest()),
                  template72=dict(selectors=selectors), template92_selectors=[19, 882, 897], props=props, prop473=pillar, sounds=sounds,
                  hit_order='AE2C8: records scanned in order, first admitted record runs (count check at AE300)',
                  files=files,
                  adapters=['frames advance at 10 frames/s (native animation clock not replayed)',
                            'durability = placement byte30, reduced by each landed hit damage (port melee/Spark damage); mode4 admits when threshold >= remaining',
                            'melee context 2/4 and Spark 1/1 as for the other cave hit owners'])
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS cave stalactites: %d props, %d selector images, %d sounds' % (len(props), len(selectors), len(sounds)))


if __name__ == '__main__':
    main()
