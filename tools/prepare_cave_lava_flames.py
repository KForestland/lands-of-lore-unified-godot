#!/usr/bin/env python3
"""Pin the L1_DC lava-chamber flames: templates 69/70/71 (props 281..328), omitted by the recovered prop preview.

Playtest 2026-10-17 report11:03:19 ("looks good, but we are missing the roaches here") looks across the lava
chamber below the roach nest. The chamber's source placements hold no creature there (the nearest actors are the
WORM pair 36/37, already hosted by cave_lurking_roach); what the recovered preview omits are 48 animated props:
templates 69, 70 and 71, one selector each, all descriptor 126 (seven flame frames). They differ only in state size
(height byte 250/150/75). No command group, region, control or actor references any of them: they are ambient.
Placement byte -5 repeats the template index; byte -3 (0..11 here) is read, modulo the 7 frames, as the start phase.
Usage: prepare_cave_lava_flames.py --output scripts/lol2/cave_lava_flames_source.json
"""
import argparse, hashlib, json, shutil, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('~/lol2_out/all_maps_20260922/L1_DC')
TEMPLATES = (69, 70, 71)
DESCRIPTOR = 126
RECORDS = range(281, 329)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    out = ROOT / 'assets/lol2/generated/cave_lava_flames'
    if out.exists(): sys.exit('refusing to overwrite ' + str(out))
    sys.path.insert(0, str(Path(__file__).resolve().parent / 'lol2'))
    from map_props import load_templates
    from lol2_source_format import parse_mix
    area, arc, entry, raw, owners, streams = source_area('L1_DC')
    meta = next(arc[e['offset']:e['offset'] + e['size']] for e in parse_mix(arc) if e['key'] == 2971019266)
    templates = load_templates(meta)['templates']
    sizes = {}
    for t in TEMPLATES:
        sels = templates[t]['selectors']
        assert len(sels) == 1 and [f['descriptor'] for f in sels[0]['frames']] == [DESCRIPTOR], t
        sizes[t] = sels[0]['state_height']
    assert sizes == {69: 250, 70: 150, 71: 75}, sizes
    # Ambient: no owner group belongs to these props and no command anywhere targets one (kind3 prop operand).
    assert not [o for o in owners if o['owner_kind'] == 'prop' and o['owner'] in RECORDS]
    ids = {struct.pack('<H', r).hex() for r in RECORDS}
    for stream in streams:
        for cmds in (stream.values() if isinstance(stream, dict) else stream):
            for c in cmds:
                h = c['raw_hex']
                assert not (len(h) >= 8 and h[2:4] == '03' and h[4:8] in ids), h
    exported = [q for q in json.loads((MAP / 'props/props.json').read_text())['props'] if q['template'] in TEMPLATES]
    assert sorted(q['record'] for q in exported) == list(RECORDS)
    review = json.loads((MAP / 'review.json').read_text())
    frames = review['animations'][f'prop_{DESCRIPTOR}']['frames']
    assert len(frames) == 7
    props = {}
    for q in sorted(exported, key=lambda q: q['record']):
        placement = bytes.fromhex(q['placement_hex'])
        assert q['animated'] and q['material'] == f'prop_{DESCRIPTOR}' and placement[-5] == q['template'] and placement[-3] < 16, q['record']
        props[str(q['record'])] = dict(template=q['template'], position=q['position'], region=q['region'],
                                       left=q['left'], right=q['right'], bottom=q['bottom'], top=q['top'],
                                       start_frame=placement[-3] % len(frames), placement_phase=placement[-3])
    out.mkdir(parents=True)
    names = []
    for i, f in enumerate(frames):
        name = f'{DESCRIPTOR}_{i}_index.png'; shutil.copyfile(MAP / f.replace('.png', '_index.png'), out / name); names.append(name)
    files = {n.name: hashlib.sha256(n.read_bytes()).hexdigest() for n in sorted(out.iterdir())}
    result = dict(version=1, source=dict(area='L1_DC', archive_sha256=hashlib.sha256(arc).hexdigest()),
                  descriptor=DESCRIPTOR, frames=names, template_heights={str(k): v for k, v in sizes.items()},
                  props=props, files=files,
                  adapters=['frames advance at 10 frames/s (native animation clock not replayed)',
                            'placement byte -3 modulo 7 used as the start frame (values 0..11; field meaning not traced natively)',
                            'no collision, hit or damage: none is present in the source records'])
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS cave lava flames: %d props, %d frames' % (len(props), len(names)))


if __name__ == '__main__':
    main()
