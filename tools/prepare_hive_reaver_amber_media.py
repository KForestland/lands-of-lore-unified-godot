#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/hive_reaver_amber pack from explicit original game files.

  python3 tools/prepare_hive_reaver_amber_media.py --game GAME --amber-source scripts/lol2/hive_reaver_amber_source.json \
      --pillars-source scripts/lol2/hive_reaver_pillars_source.json --output-root FRESH

Selections come from the two published runtime contracts written by prepare_hive_reaver_amber.py and
prepare_hive_reaver_pillars.py (both unchanged; their legacy entry points still regenerate the contracts):
- control material images m%04d.png = the resource ids of the contract's control 121/123 faces;
- item icons reaver.png/amber.png = the contract's item definitions (17 "18-Reaver of GO", 112 "110-Amber");
- pillar.png = the first frame of prop 59, checked against the pillars contract's image sha256.
Images are produced with published code only, in a temporary directory: lol2/map_materials.export_materials and
lol2/map_props.export_props for L5_HC, and prepare_museum_key_locks.icon. Nothing is written to the output root until
every input, original and the pillar hash are checked. No historical export, no RE checkout, no native replay.
"""
import argparse, hashlib, json, shutil, struct, sys, tempfile
from pathlib import Path

AMBER_SHA256 = '38fa2d6dccfabb2efba9e32602c31ca019cfab93bc51801a0d7ad290099d04e5'    # scripts/lol2/hive_reaver_amber_source.json
PILLARS_SHA256 = '2beb685686490511639e87d7eb5b5c699af3a60ed75c33f93c9adb4bdd310c91'  # scripts/lol2/hive_reaver_pillars_source.json
ORIGINALS = {'DAT/L5_HC.MIX': 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8',
             'GLOBAL.MIX': '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd',
             'LOCAL.MIX': 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278'}
PACK = 'assets/lol2/generated/hive_reaver_amber'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def selections(amber, pillars):
    """(resource ids, {icon file: definition}, pillar sha256) from the published contracts."""
    rids = set()
    for control, template in [('121', 29), ('123', 27)]:
        c = amber['controls'][control]; assert c['template'] == template, control
        for f in c['faces']:
            assert f['material'] == 'm%04d.png' % f['resource_id'], f['material']
            rids.add(f['resource_id'])
    icons = {'reaver.png': amber['reaver']['item'], 'amber.png': amber['amber']['item']}
    assert pillars['image']['file'] == 'pillar.png'
    return sorted(rids), icons, pillars['image']['sha256']


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'amber-source', 'pillars-source', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    tools = Path(__file__).resolve().parent
    sys.path[:0] = [str(tools), str(tools / 'lol2')]
    for path, want, label in [(a.amber_source, AMBER_SHA256, 'Reaver/Amber contract'), (a.pillars_source, PILLARS_SHA256, 'Reaver pillars contract')]:
        if not path.is_file(): p.error('Missing input: ' + str(path))
        if digest(path.read_bytes()) != want: p.error(f'{path}: not the pinned published {label} ({want})')
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    amber, pillars = json.loads(a.amber_source.read_text()), json.loads(a.pillars_source.read_text())
    from prepare_museum_key_locks import definitions, icon
    from lol2_source_format import u32
    try:
        assert amber['source']['sha256'] == pillars['source']['sha256'] == ORIGINALS['DAT/L5_HC.MIX'], 'contract archive'
        rids, icons, pillar_sha = selections(amber, pillars)
        blob, base, count, names = definitions(game=a.game)
        for item in icons.values():
            d = blob[base + item['definition'] * 91:base + (item['definition'] + 1) * 91]
            assert names[item['definition']] == item['name'] and u32(d, 24) == item['identity'] and d[0x42] == item['handler'], item['name']
    except (AssertionError, KeyError, StopIteration, ValueError, IndexError, TypeError, struct.error) as error:
        p.error('Inputs do not match the published contracts/originals: ' + (str(error) or type(error).__name__))
    import map_materials, map_props
    with tempfile.TemporaryDirectory(prefix='hive-reaver-amber-') as tmp:
        tmp = Path(tmp)
        try:
            map_materials.export_materials(a.game, 'L5_HC', tmp / 'materials')
            map_props.export_props(a.game, 'L5_HC', tmp / 'props', tmp / 'materials')
            (tmp / 'icons').mkdir()
            for name, item in icons.items(): icon(item['definition'], tmp / 'icons' / name, game=a.game)
        except (AssertionError, ValueError, KeyError, OSError) as error:
            p.error('Published exporters refused the originals: ' + str(error))
        staged = {('m%04d.png' % r): tmp / 'materials' / ('material_%04d' % r) / 'mip_0_palette.png' for r in rids}
        staged.update({name: tmp / 'icons' / name for name in icons})
        staged['pillar.png'] = tmp / 'props/sprites/prop_59_frame_0.png'
        missing = [str(v) for v in staged.values() if not v.is_file()]
        if missing: p.error('Published exporters produced no ' + ', '.join(missing))
        if digest(staged['pillar.png'].read_bytes()) != pillar_sha: p.error('prop 59 frame 0 differs from the published pillar image sha256')
        out = a.output_root / PACK; out.mkdir(parents=True)
        for name, source in sorted(staged.items()): shutil.copyfile(source, out / name)
    print('PASS hive_reaver_amber:', len(staged), 'images (%d materials, 2 icons, pillar)' % len(rids))


if __name__ == '__main__':
    main()
