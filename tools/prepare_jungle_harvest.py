#!/usr/bin/env python3
"""Pin the renewable Jungle Aloe plants and Ironwood sap trees and export their selector images and item icons.

Aloe plants props254-260/311 (template104, selectors 0..3 = owner state, 3 = bare):
  kind4 mode0 (empty hand) state0/1/2: op14 sub3 enables kind2 timers 0 / 0,1 / 0,1,2, owner state and selector +1,
      op3 player "107-Aloe" (identity 0xBFDDCCA3, property4: one item). State3 has no use record.
  kind2 timers 0/1/2 (flags 0x80 -> minutes: 15 x 60 x 60 = 54000 ticks, record counter 0xD2F0 = 54000, initially
      stopped, periodic): predicate state==1/2/3 -> op14 sub4 stops that timer, state and selector -1.
Prop1464 (template52, a single Aloe plant): kind4 mode0 while state<3: op17 state+1, op3 "107-Aloe" (property1).
  kind9 hit (wildcard masks, mode1 damage>=1, one-shot): op20 sound, state4, selector1. No timer: 3 Aloe at most.
Ironwood sap trees props261-267/310 (template105, selector0 closed, 1 tapped):
  kind9 hit (masks 0x010E/0x0004, mode4: remaining durability <= 3; placement durability 4) at state0: selector1,
      op7 (presentation), state1.
  kind4 mode0 state1/2/3: op14 sub3 enables timer0, state+1, op3 "109-Ironwod sap" (identity 0x64C08B10, property4).
  kind2 timer0 (flags 0x80, 18 minutes = 64800 ticks, periodic) at state>0: op17 state-1.
  kind6 event3 (animation end) at state0: selector0, op14 sub4 stops timer0.
Native timer semantics (B47B4 sub3/sub4, B8AC4 duration, B8BA0 tick): sub3 enables a stopped record without resetting
its counter, sub4 stops it keeping the counter; a running record counts down and on expiry reloads (with carry) and
offers its group, which runs only when its predicate holds.
Usage: prepare_jungle_harvest.py --output scripts/lol2/jungle_harvest_source.json --asset-dir assets/lol2/generated/jungle_harvest
"""
import argparse, hashlib, json, shutil, struct
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section, parse_mix
from prepare_jungle_exit_encounter import predicate
from lol2 import map_props as props

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('/home/bob/lol2_out/all_maps_20260922/L4_HJ')
PLANTS = [254, 255, 256, 257, 258, 259, 260, 311]
TREES = [261, 262, 263, 264, 265, 266, 267, 310]
SINGLE = 1464
ALOE = dict(identity=0xBFDDCCA3, name='107-Aloe', definition=109, handler=9)
SAP = dict(identity=0x64C08B10, name='109-Ironwod sap', definition=111, handler=98)
TICKS = 60


def grant(item, prop):
    return '03010000' + struct.pack('<I', item['identity']).hex() + '%02x000000' % prop


def records(owners, streams, arc, table, n):
    out = []
    for r in [r for r in owners if r['owner_kind'] == 'prop' and r['owner'] == n]:
        raw = arc[r['archive_offset']:r['archive_offset'] + arc[r['archive_offset']]]
        out.append(dict(kind=r['event'], group=r['group'], predicate=r['predicate'],
                        predicate_raw=predicate(table, r['predicate'])['raw'] if r['predicate'] is not None else None,
                        commands=[c['raw_hex'] for c in streams[r['stream']][r['group']]], raw=raw.hex()))
    return out


def timer(rec, minutes):
    b = bytes.fromhex(rec['raw'])
    # +4 flags 0x80 (minutes), +5 bit0 (initially stopped), +6/+7 range, +8 counter in ticks.
    assert len(b) == 10 and b[4] == 0x80 and b[5] == 0x01 and b[6] == b[7] == minutes, rec['raw']
    assert struct.unpack_from('<H', b, 8)[0] == minutes * 60 * TICKS, rec['raw']
    return dict(group=rec['group'], predicate=rec['predicate_raw'], commands=rec['commands'], period_seconds=minutes * 60.0)


def plant(rs, n):
    own = n.to_bytes(2, 'little').hex()
    use = {r['predicate_raw']: r for r in rs if r['kind'] == 4}
    timers = [r for r in rs if r['kind'] == 2]
    assert len(rs) == 6 and set(use) == {'0005000000', '0005000001', '0005000002'} and len(timers) == 3, n
    for s in range(3):
        want = ['0e03%s03000%d00' % (own, t) for t in range(s + 1)]
        c = use['000500000%d' % s]['commands']
        assert [x for x in c if x.startswith('0e03')] == want and '1003%s%02x00' % (own, s + 1) in c and '0503%s%02x00' % (own, s + 1) in c and c.count(grant(ALOE, 4)) == 1 and len(c) == s + 4, (n, c)
    out = []
    for t, rec in enumerate(timers):
        assert rec['predicate_raw'] == '000500000%d' % (t + 1) and rec['commands'] == ['0e03%s04000%d00' % (own, t), '1003%s%02x00' % (own, t), '0503%s%02x00' % (own, t)], (n, rec)
        out.append(timer(rec, 15))
    return dict(use={str(s): use['000500000%d' % s]['group'] for s in range(3)}, timers=out)


def tree(rs, n):
    own = n.to_bytes(2, 'little').hex()
    hit = [r for r in rs if r['kind'] == 9]; use = {r['predicate_raw']: r for r in rs if r['kind'] == 4}
    anim = [r for r in rs if r['kind'] == 6]; timers = [r for r in rs if r['kind'] == 2]
    assert len(rs) == 6 and len(hit) == len(anim) == len(timers) == 1 and set(use) == {'0005000001', '0005000002', '0005000003'}, n
    h = bytes.fromhex(hit[0]['raw'])
    assert struct.unpack_from('<HH', h, 4) == (0x010E, 0x0004) and h[8] == 3 and h[9] == 0x04 and hit[0]['predicate_raw'] == '0005000000', hit[0]
    assert hit[0]['commands'] == ['0503%s0100' % own, '0703%s0000' % own, '1003%s0100' % own], hit[0]
    for s in (1, 2, 3):
        assert use['000500000%d' % s]['commands'] == ['0e03%s03000000' % own, '1003%s%02x00' % (own, s + 1), grant(SAP, 4)], (n, s)
    assert bytes.fromhex(anim[0]['raw']) == bytes([6, 6]) + anim[0]['group'].to_bytes(2, 'little') + bytes([3, 0]) and anim[0]['predicate_raw'] == '0005000000'
    assert anim[0]['commands'] == ['0503%s0000' % own, '0e03%s04000000' % own], anim[0]
    assert timers[0]['predicate_raw'] == '0405000000' and timers[0]['commands'] == ['1103%sff00' % own]
    return dict(hit=dict(group=hit[0]['group'], mask0=0x010E, mask2=0x0004, mode=4, threshold=3), use={str(s): use['000500000%d' % s]['group'] for s in (1, 2, 3)},
                animation_end=anim[0]['group'], timer=timer(timers[0], 18))


def single(rs, n):
    own = n.to_bytes(2, 'little').hex()
    assert len(rs) == 2
    use = next(r for r in rs if r['kind'] == 4); hit = next(r for r in rs if r['kind'] == 9)
    assert use['predicate_raw'] == '0505000003' and use['commands'] == ['1103%s0100' % own, grant(ALOE, 1)], use
    h = bytes.fromhex(hit['raw'])
    assert struct.unpack_from('<HH', h, 4) == (0, 0) and h[8] == 1 and h[9] == 0x81 and hit['predicate'] is None, hit
    assert hit['commands'][1:] == ['1003%s0400' % own, '0503%s0100' % own] and hit['commands'][0].startswith('1403' + own), hit
    return dict(use=use['group'], hit=dict(group=hit['group'], mode=1, threshold=1, one_shot=True, sound_command=hit['commands'][0]))


def selectors(arc, template, out_dir, stem):
    meta = next(e for e in parse_mix(arc) if e['key'] == 3710142494)
    templates = props.load_templates(arc[meta['offset']:meta['offset'] + meta['size']])['templates']
    tex = (MAP / 'materials/texture.bin').read_bytes()
    report = json.loads((MAP / 'materials/materials.json').read_text())
    assert hashlib.sha256(tex).hexdigest() == report['source_hash']['decoded_texture_sha256']
    sec = props.mm.sections(tex); rgb = props.mm.rgb_palette(tex[props.u32(tex, 4):][:768], 6)
    tmp = out_dir / '_build'; (tmp / 'sprites').mkdir(parents=True, exist_ok=True)
    rows = []
    for s in templates[template]['selectors']:
        assert len(s['frames']) == 1, (template, s['selector'])
        frame = s['frames'][0]
        image = props.build_image(frame['descriptor'], tex, sec, rgb, tmp / 'sprites', tmp, {})
        src = tmp / (image.get('frames', [image['image']])[0]); name = '%s_%d.png' % (stem, s['selector'])
        shutil.copyfile(src, out_dir / name)
        rows.append(dict(selector=s['selector'], descriptor=frame['descriptor'], image=name, left=frame['left'], right=frame['right'],
                         sha256=hashlib.sha256((out_dir / name).read_bytes()).hexdigest()))
    shutil.rmtree(tmp)
    return rows


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True); p.add_argument('--asset-dir', type=Path, required=True)
    a = p.parse_args(); a.asset_dir.mkdir(parents=True, exist_ok=True)
    area, arc, entry, raw, owners, streams = source_area('L4_HJ')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    _, _, placements = section(raw, 0x14, 0x60, 37)
    exported = {q['record']: q for q in json.loads((MAP / 'props/props.json').read_text())['props']}
    def place(n, template, durability):
        q = exported[n]; assert q['template'] == template and q['selector'] == 0, n
        assert placements[n * 37 + 30] == durability, (n, placements[n * 37 + 30])
        return dict(position=q['position'], region=q['region'])
    plants = {str(n): dict(plant(records(owners, streams, arc, table, n), n), **place(n, 104, 21)) for n in PLANTS}
    trees = {str(n): dict(tree(records(owners, streams, arc, table, n), n), **place(n, 105, 4)) for n in TREES}
    lone = dict(single(records(owners, streams, arc, table, SINGLE), SINGLE), **place(SINGLE, 52, 200))
    # Item definitions (handler9 = Aloe's fixed +5 pending heal, shared with "108-Cave aloe"; handler98 = sap).
    import sys; sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_museum_key_locks import definitions, icon
    from build_game_atlas import u32
    blob, base, n, names = definitions()
    for item in (ALOE, SAP):
        d = blob[base + item['definition'] * 91:base + (item['definition'] + 1) * 91]
        assert names[item['definition']] == item['name'] and u32(d, 24) == item['identity'] and d[0x42] == item['handler'], item
    icon(ALOE['definition'], a.asset_dir / 'aloe.png'); icon(SAP['definition'], a.asset_dir / 'sap.png')
    art = dict(plant=selectors(arc, 104, a.asset_dir, 'plant'), tree=selectors(arc, 105, a.asset_dir, 'tree'), single=selectors(arc, 52, a.asset_dir, 'single'))
    assert [len(art[k]) for k in ('plant', 'tree', 'single')] == [4, 2, 2]
    result = dict(version=1, source=area['source'], aloe=ALOE, sap=SAP, plants=plants, trees=trees, single={str(SINGLE): lone}, art=art,
                  ticks_per_second=TICKS,
                  adapters=['E with an empty hand at an aimed, reachable, unoccluded plant or tree is the kind4 mode0 producer',
                            'an armed melee strike (context masks 2/4, damage>=1) is the kind9 producer for trees and prop1464; Spark (1/1) does not match the tree masks and is not hosted for prop1464',
                            'tree event3 (animation end) at state0 is applied as soon as the timer returns a tree to state0 (single-frame selectors; native event3 timing not replayed)',
                            'timers run on the active Jungle world clock at 60 ticks/s (consistent with every record counter = minutes*60*60)',
                            'op7 and the prop1464 op20 sound are presentation (not hosted)'],
                  pools=dict(aloe=len(PLANTS) * 3 + 3, sap=len(TREES) * 3))
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS jungle harvest: %d plants, %d trees, prop%d; pools %s' % (len(plants), len(trees), SINGLE, result['pools']))


if __name__ == '__main__':
    main()
