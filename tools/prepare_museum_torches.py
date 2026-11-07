#!/usr/bin/env python3
"""Pin the L3_DH torch switch puzzle and the 35 Museum wall torches from the original archive records.

Records (PROVEN, read with tools/verify_actor_item_grants.source_area):
  movable52 (template70, the wall plate in niche region1475/1476) kind4 mode0 (empty hand), group12092:
      op16 prop61 state1.  kind6 value16 (a travel end of the movable, 63740/63890), group12104: op16 prop61 state0.
  prop61 (template42, the small pilot flame in the niche, durability byte30 = 2):
      kind9 masks 0x0011/0x0001, threshold1, mode4, one-shot, predicate207 (owner state == 1), group0:
          op9 self property21 (raises event20), op6 self sub5/6/3/4, op5 self selector1 (the flare, descriptor1),
          op6 self sub1 (animation restart), op9 self property18, op20 sound 0x2E4, op2 player sub0x10 arg1
          (one magic level: D88CD, thresholds[level] - experience).
      kind6 value20, group70: op19 hit (masks 0x0001/0x0001, damage 5) on each of 35 torch props, op208
          (sub0x90, intensity5, duration 2: a screen shake), op20 sound 0x19B at prop63, op16 self state1.
  35 torch props (template22, durability 1; 63/68/69/227/228 masks 0x0011/0x0001, the rest 0x0001/0x0001):
      kind9 threshold1 mode4, not one-shot, no predicate: op6 self sub5/6/3/4, op5 self selector2,
      op6 self sub1, op9 self property18, op20 sound 0x2E4.
Template22 draws a chained pair (native F1A94: state byte11 bit0 also draws the next state at the same anchor):
  selector0 = holder 954 + embers 949 (unlit), selector2 = lit holder 939 + flame 944 (same 74x193 canvas and trims). Template42: selector0 = pilot 944 (3x9 units),
  selector1 = flare descriptor1 (7 frames).
Sprites come from a fresh tools/lol2/map_props.export_props of the original L3_DH.MIX; movable52's six faces from
the all-maps review export (same source archive). Sounds 740 (0x2E4) and 411 (0x19B) from the original sound bank.
Usage: prepare_museum_torches.py --game GAME --review L3_DH_REVIEW_JSON --output scripts/lol2/museum_torches_source.json
"""
import argparse, hashlib, json, os, struct, sys, tempfile
from pathlib import Path
from PIL import Image
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ROOT = Path(__file__).resolve().parents[1]
REVIEW_SHA = '8af16e5dcc1e02a2fa8eea985649211993a5771b41b7fb183e5cb1e45258ab8d'
PILOT, SWITCH = 61, 52
SOUND_LIGHT, SOUND_ALL = 740, 411
LIGHT_TAIL = ['0603%s0532', '0603%s06fa', '0603%s031e', '0603%s0432', '0503%s0200', '0603%s0100',
              '0903%s1200', '1403%se40280020a14']


def le(n):
    return struct.pack('<H', n).hex()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game', type=Path, default=Path(os.environ.get('LOL2_GAME_ROOT', '~/lol2_runtime_root')))
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--review', type=Path, required=True, help='Pinned L3_DH all-maps geometry review JSON')
    a = p.parse_args()
    review_bytes = a.review.read_bytes()
    if hashlib.sha256(review_bytes).hexdigest() != REVIEW_SHA:
        sys.exit('refusing unverified geometry review: ' + str(a.review))
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    out = ROOT / 'assets/lol2/generated/museum_torches'
    if out.exists(): sys.exit('refusing to overwrite ' + str(out))
    sys.path.insert(0, str(Path(__file__).resolve().parent / 'lol2'))
    from map_props import export_props, load_templates
    from lol2_source_format import parse_mix
    area, arc, entry, raw, owners, streams = source_area('L3_DH', game=a.game)
    _, _, table = section(raw, 0xbc, 0xb8, 5)

    def records(kind, index):
        rows = []
        for o in owners:
            if o['owner_kind'] != kind or o['owner'] != index: continue
            rows.append(dict(group=o['group'], kind=o['event'],
                             raw=arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]].hex(),
                             predicate=predicate(table, o['predicate']) if o['predicate'] is not None else None,
                             commands=[c['raw_hex'] for c in streams[o['stream']][o['group']]]))
        return rows

    # movable52: the switch plate.
    sw = records('movable', SWITCH)
    assert [(r['kind'], r['raw']) for r in sw] == [(4, '0a043c2f000000000000'), (6, '0606482f1000')], sw
    assert sw[0]['commands'] == ['10033d000100'] and sw[1]['commands'] == ['10033d000000'] and all(r['predicate'] is None for r in sw)
    # prop61: the pilot flame.
    pr = records('prop', PILOT)
    assert [(r['kind'], r['raw']) for r in pr] == [(9, '0a090000110001000184'), (6, '060646001400')], pr
    assert pr[0]['predicate']['raw'] == '0005000001' and pr[1]['predicate'] is None
    oid = le(PILOT)
    assert pr[0]['commands'] == ['0903%s1500' % oid, '0603%s0532' % oid, '0603%s06fa' % oid, '0603%s031e' % oid,
                                 '0603%s0432' % oid, '0503%s0100' % oid, '0603%s0100' % oid, '0903%s1200' % oid,
                                 '1403%se40280020a14' % oid, '020100001001'], pr[0]['commands']
    hits = pr[1]['commands']
    assert hits[-3:] == ['d090000000050200', '14033f009b01ff110f1f', '10033d000100'], hits[-3:]
    order = []
    for c in hits[:-3]:
        assert c.startswith('1303') and c[8:] == '010001000500', c
        order.append(struct.unpack('<H', bytes.fromhex(c[4:8]))[0])
    assert len(order) == 35 and len(set(order)) == 35, order

    # Fresh prop export from the original archive (sprites, templates, placements).
    scratch = Path(tempfile.mkdtemp(prefix='museum_torches_'))
    report = export_props(a.game, 'L3_DH', scratch)
    exported = {q['record']: q for q in report['props']}
    meta = next(arc[e['offset']:e['offset'] + e['size']] for e in parse_mix(arc) if e['key'] == 3105896470)
    templates = load_templates(meta)['templates']
    t22, t42 = templates[22], templates[42]
    assert [s['frames'][0]['descriptor'] for s in t22['selectors']] == [954, 949, 939, 944]
    assert [int(s['state_hex'][22:24], 16) & 1 for s in t22['selectors']] == [1, 0, 1, 0]  # byte11 bit0: chain next
    assert [s['frames'][0]['descriptor'] for s in t42['selectors']] == [944, 1]
    assert [int(s['state_hex'][22:24], 16) & 1 for s in t42['selectors']] == [0, 0]

    def geometry(sel):
        f0 = sel['frames'][0]
        return dict(left=f0['left'], right=f0['right'], bottom=f0['bottom'], top=sel['state_height'] - f0['top_trim'])

    torches = {}
    for t in order:
        q = exported[t]; rows = records('prop', t); o = le(t)
        assert q['template'] == 22 and q['selector'] == 0, t
        assert len(rows) == 1 and rows[0]['kind'] == 9 and rows[0]['predicate'] is None, (t, rows)
        b = bytes.fromhex(rows[0]['raw'])
        assert b[6:10] == bytes.fromhex('01000104') and b[4:6] in (bytes.fromhex('0100'), bytes.fromhex('1100')), (t, rows[0]['raw'])
        assert rows[0]['commands'] == [c % o for c in LIGHT_TAIL], (t, rows[0]['commands'])
        placement = bytes.fromhex(q['placement_hex'])
        assert placement[30] == 1, t
        torches[str(t)] = dict(position=q['position'], region=q['region'], mask0=struct.unpack_from('<H', b, 4)[0],
                               durability=placement[30], record=rows[0]['raw'], group=rows[0]['group'])
    q = exported[PILOT]
    assert q['template'] == 42 and q['selector'] == 0 and bytes.fromhex(q['placement_hex'])[30] == 2
    pilot = dict(position=q['position'], region=q['region'], durability=2, records=pr)

    out.mkdir(parents=True)
    art = {}

    def frames(descriptor):
        anim = report['animations'].get(f'prop_{descriptor}')
        paths = [scratch / f for f in anim['frames']] if anim else [scratch / 'sprites' / f'prop_{descriptor}.png']
        assert all(p.is_file() for p in paths), descriptor
        return [Image.open(p).convert('RGBA') for p in paths]

    def write(name, image):
        image.save(out / name); return name

    # Chained pairs (native: base selector0/2, then its chained overlay selector1/3 at the same anchor) stay
    # separate layers: the overlays carry frame flag 0x10 and are drawn additively by the host.
    for key, descriptor in (('holder_unlit', 954), ('embers', 949), ('holder_lit', 939), ('flame', 944), ('flare', 1)):
        ims = frames(descriptor)
        if key != 'flare': assert all(im.size == (74, 193) for im in ims), descriptor
        art[key] = [write(f'{key}_{i}.png', im) for i, im in enumerate(ims)]
    art['pilot'] = art['flame']  # template42 selector0 is descriptor 944 drawn at 3x9 units
    assert [len(art[k]) for k in ('holder_unlit', 'embers', 'holder_lit', 'flame', 'flare')] == [1, 5, 5, 5, 7], \
        {k: len(v) for k, v in art.items()}

    review = json.loads(review_bytes)
    faces = [dict(points=f['points'], uv=f['uv'], material=f['material']) for f in review['faces']
             if f.get('placement') == SWITCH and f.get('placement_kind') == 'movable']
    assert len(faces) == 6 and all(f['material'] == '31' for f in faces), faces
    xs = sorted({p[0] for f in faces for p in f['points']}); hs = sorted({p[1] for f in faces for p in f['points']})
    assert xs == [-1890.0, -1875.0] and hs == [30, 45], (xs, hs)

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_creature_audio_clips import stage_clips
    clips = stage_clips(ROOT, 'museum_torches', [SOUND_LIGHT, SOUND_ALL], game=a.game)
    files = {n.name: hashlib.sha256(n.read_bytes()).hexdigest() for n in sorted(out.iterdir()) if n.suffix in ('.png', '.wav')}
    result = dict(
        version=1,
        source=dict(area='L3_DH', archive_sha256=hashlib.sha256(arc).hexdigest(),
                    review=str(a.review), review_sha256=hashlib.sha256(review_bytes).hexdigest()),
        templates={'22': dict(unlit=geometry(t22['selectors'][0]), lit=geometry(t22['selectors'][2]),
                              unlit_layers=['holder_unlit', 'embers'], lit_layers=['holder_lit', 'flame'],
                              chain='state byte11 bit0 draws the next state at the same anchor (F1A94)'),
                   '42': dict(pilot=geometry(t42['selectors'][0]), flare=geometry(t42['selectors'][1]))},
        art=art, torches=torches, order=order, pilot=pilot,
        switch=dict(movable=SWITCH, records=sw, faces=faces,
                    aim=[(xs[0] + xs[1]) / 2, (hs[0] + hs[1]) / 2, -1018.5]),
        event20=dict(group=70, hit=dict(mask0=1, mask2=1, damage=5), shake='d090000000050200',
                     sound=dict(request=SOUND_ALL, at=63), state=1),
        award=dict(op='020100001001', sub=0x10, arg=1, meaning='one magic level (D88CD: thresholds[level] - experience)'),
        sounds={str(k): dict(file=f'{k}.wav', name=v['name'], duration=round(v['duration'], 4)) for k, v in clips.items()},
        files=files,
        not_hosted=['op6 sub5/6/3/4 property writes on each lit torch (0x32/0xFA/0x1E/0x32; meaning UNKNOWN, likely '
                    'light radius/intensity for the lighting chunk)',
                    'op9 property18 on lit torches and prop61 (UNKNOWN)',
                    'op208 screen shake (sub0x90, intensity5, 2 s) in group70',
                    'movable52 travel: kind6 value16 (a travel end) resets prop61 to state0, but what starts the '
                    'plate\'s travel is not traced; the plate is drawn still and the reset never fires',
                    'Firestorm/fire-crystal hits (mask0 bit0x10): only the Spark context 1/1 is delivered'],
        adapters=['animations at 10 frames/s (native sequence rate unverified, as the all-maps export)',
                  'frame-flag-0x10 overlays (embers, flame, pilot, flare) drawn additively: their dark smoke pixels '
                  'would otherwise cover the bracket (longplay f_00265 shows a lit torch without a dark halo)',
                  'hit volumes: torch = sprite width x 63 x 8 units; pilot = 16 x 16 x 16 units around the flame '
                  '(native template depth byte30 = 229 would block the corridors)',
                  'E (empty hand, within reach) on the plate stands for the native kind4 mode0 click',
                  'Spark context 1/1 with port damage 8; group70 hits use damage 5 as recorded'])
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS museum torches: %d torches, pilot prop%d, switch movable%d, %d art frames, sounds %d/%d' %
          (len(torches), PILOT, SWITCH, sum(len(v) for v in art.values()), SOUND_LIGHT, SOUND_ALL))


if __name__ == '__main__':
    main()
