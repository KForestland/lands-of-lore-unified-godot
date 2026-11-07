#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_long_arm pack (floors.json, frame_00..14.png, icon.png) from explicit
original game files and freshly generated inputs.

  python3 tools/prepare_museum_long_arm_media.py --game GAME --source scripts/lol2/museum_long_arm_source.json \
      --recipe scripts/lol2/museum_review_selection_source.json \
      --museum-review assets/lol2/generated/museum_review/museum.json --output-root FRESH

prepare_museum_long_arm.py (unchanged; still writes the published contract) builds floors.json by rerunning
build_museum_review.py on historical exports. Here, in a temporary directory, the builder's inputs are regenerated from the
originals with published readers: lol2/map_geometry.export_geometry, lol2/map_materials.export_materials,
lol2/map_surfaces.source_tables/resolve_resource (floor/ceiling selector words 16/17 -> preset, resource),
lol2_rotation_table.rotation_table. The compact recipe supplies only the two recorded runtime selections the builder needs
(captured material set, deferred ceilings). The rebuilt base faces must equal --museum-review's faces (the museum_review
pack the closed face indices refer to); its sha256 is recorded as floors.json shipped_sha256. The dropped-floor variant is
the same builder rerun with the walkway floors of prepare_museum_long_arm.FLOORS. Frames come from lol2/map_props.export_props
(checked against the contract's frame hashes); the icon from prepare_museum_key_locks.icon. Nothing is written to the output
root until every check passes. No historical export, no RE checkout, no native replay.
"""
import argparse, hashlib, json, shutil, struct, subprocess, sys, tempfile
from pathlib import Path

SOURCE_SHA256 = '9b55ee0809a3048220cfd56e008d752dcb9864db9d390588b9d001e3e382eb96'   # scripts/lol2/museum_long_arm_source.json
RECIPE_SHA256 = '501ea933b9944ab7cfc893446fef346d142861ee53f96c137865a42b9348b477'   # scripts/lol2/museum_review_selection_source.json
ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac',
             'GLOBAL.MIX': '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd',
             'LOCAL.MIX': 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278'}
PACK = 'assets/lol2/generated/museum_long_arm'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def builder_inputs(game, tmp, recipe, geometry, ms, rotation_table):
    """presets/surface setup/materials/rotation table/arrival in the builder's input formats, from published readers."""
    area, raw, presets = ms.source_tables(game, 'L3_DH')
    blob = (tmp / 'materials/texture.bin').read_bytes()
    deferred = set(recipe['ceiling_deferred'])
    regions, ceilings = [], []
    for r in json.loads(geometry.read_text())['regions']:
        w = struct.unpack('<22H', bytes.fromhex(r['raw_hex']))
        for sel, dest, ceiling in [(w[16] & 255, regions, False), (w[16 if w[14] & 128 else 17] & 255, ceilings, True)]:
            if sel == 255 or sel >= len(presets) or (ceiling and r['id'] in deferred): continue
            k, _ = ms.resolve_resource(presets[sel]['resource'], blob); dest.append(dict(region=r['id'], preset=sel, resource_index=k))
    pres = tmp / 'builder/presets.json'; pres.parent.mkdir(); pres.write_text(json.dumps(dict(regions=regions, ceiling_regions=ceilings)))
    bits = {2.0: 0, 1.0: 1, 0.5: 2, 0.25: 3}
    setup = dict(presets_sha256=digest(pres.read_bytes()), results=[dict(preset=x['index'], initial_flags=0, angle_word=x['angle'], offset_x_fixed=x['offset_x'],
                 offset_y_fixed=x['offset_y'], offset_bytes=list(x['offsets']), flags=bits[x['scale']] << 14) for x in presets])
    (tmp / 'builder/setup.json').write_text(json.dumps(setup))
    (tmp / 'builder/rotation_table.bin').write_bytes(rotation_table(game))
    report = json.loads((tmp / 'materials/materials.json').read_text()); keep = set(recipe['material_indices'])
    assert keep <= {m['index'] for m in report['materials']}, 'captured material set not in the export'
    report['materials'] = [dict(m, **({'review_fps': recipe['review_fps'][str(m['index'])]} if str(m['index']) in recipe['review_fps'] else {}))
                           for m in report['materials'] if m['index'] in keep]
    sel = tmp / 'builder/materials'; sel.mkdir()
    for m in report['materials']: shutil.copytree(tmp / 'materials' / ('material_%04d' % m['index']), sel / ('material_%04d' % m['index']))
    (sel / 'materials.json').write_text(json.dumps(report))
    return pres, tmp / 'builder/setup.json', sel, tmp / 'builder/rotation_table.bin'


def build(tools, game, geometry, inputs, folder):
    pres, setup, mats, table = inputs
    arrival = folder.with_name(folder.name + '_arrival.json')  # start/arrival_region only; not consumed by floors.json
    arrival.write_text(json.dumps(dict(geometry_sha256=digest(geometry.read_bytes()), saves=[dict(native_xy=[0, 0], region=0, floor_height=0)])))
    args = [sys.executable, '-B', str(tools / 'build_museum_review.py'), '--game-root', str(game), '--geometry', str(geometry), '--presets', str(pres),
            '--materials', str(mats), '--arrival', str(arrival), '--surface-setup', str(setup), '--rotation-table', str(table), '--out', str(folder)]
    run = subprocess.run(args, cwd=tools, capture_output=True, text=True)
    if run.returncode: raise ValueError('build_museum_review.py failed: ' + run.stderr.strip()[-300:])
    return json.loads((folder / 'museum.json').read_text())


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'source', 'recipe', 'museum-review', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    output = a.output_root.resolve()
    for original in [a.game, a.source, a.recipe, a.museum_review]:
        original = original.resolve()
        if output == original or output in original.parents or original in output.parents:
            p.error('--output-root overlaps an input')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    for need in ['build_museum_review.py', 'export_museum_geometry.py']:
        if not (tools / need).is_file(): p.error('Missing builder file ' + str(tools / need))
    for path, want, label in [(a.source, SOURCE_SHA256, 'Long Arm contract'), (a.recipe, RECIPE_SHA256, 'Museum review selection recipe')]:
        if not path.is_file(): p.error('Missing input: ' + str(path))
        if digest(path.read_bytes()) != want: p.error(f'{path}: not the pinned {label} ({want})')
    if not a.museum_review.is_file(): p.error('Missing input: ' + str(a.museum_review))
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    source, recipe = json.loads(a.source.read_text()), json.loads(a.recipe.read_text())
    review_bytes = a.museum_review.read_bytes()
    try: review = json.loads(review_bytes)
    except ValueError: p.error(f'{a.museum_review}: not a museum_review manifest')
    from prepare_museum_long_arm import FLOORS
    from prepare_museum_key_locks import definitions, icon
    from lol2_source_format import u32
    import map_geometry, map_materials, map_props, map_surfaces
    from lol2_rotation_table import rotation_table
    try:
        assert source['source']['sha256'] == ORIGINALS['DAT/L3_DH.MIX'], 'contract archive'
        assert {int(k): v for k, v in source['floor_targets'].items()} == FLOORS, 'contract floor targets'
        item = source['item']; blob, base, count, names = definitions(game=a.game)
        assert names[item['definition']] == item['name'] and u32(blob, base + item['definition'] * 91 + 24) == item['identity'], 'item definition'
        frames = source['pedestal']['frames']; assert [f['file'] for f in frames] == ['frame_%02d.png' % i for i in range(15)], 'contract frames'
        assert isinstance(review.get('faces'), list) and review['faces'], 'museum_review faces'
    except (AssertionError, KeyError, TypeError, ValueError, IndexError) as error:
        p.error('Inputs do not match the published contract/originals: ' + (str(error) or type(error).__name__))
    with tempfile.TemporaryDirectory(prefix='museum-long-arm-') as tmp:
        tmp = Path(tmp)
        try:
            map_geometry.export_geometry(a.game, 'L3_DH', tmp / 'geometry')
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            map_props.export_props(a.game, 'L3_DH', tmp / 'props', tmp / 'materials')
            geometry = tmp / 'geometry/geometry.json'
            inputs = builder_inputs(a.game, tmp, recipe, geometry, map_surfaces, rotation_table)
            base = build(tools, a.game, geometry, inputs, tmp / 'base')
            if base['faces'] != review['faces']: p.error('Fresh museum_review rebuild differs from --museum-review faces')
            g = json.loads(geometry.read_text())
            for r in g['regions']:
                if r['id'] in FLOORS: r['floor_base'] = FLOORS[r['id']]; r['floor_corners'] = [FLOORS[r['id']]] * len(r['floor_corners'])
            dropped_geometry = tmp / 'dropped_geometry.json'; dropped_geometry.write_text(json.dumps(g))
            dropped = build(tools, a.game, dropped_geometry, inputs, tmp / 'open')
            (tmp / 'icon').mkdir(); icon(item['definition'], tmp / 'icon/icon.png', game=a.game)
        except (AssertionError, ValueError, KeyError, OSError) as error:
            p.error('Fresh preparation refused: ' + str(error))
        # floors.json exactly as prepare_museum_long_arm.floor_variant derives it.
        key = lambda f: json.dumps(f, sort_keys=True)
        base_keys = [key(f) for f in base['faces']]; open_keys = {key(f) for f in dropped['faces']}; base_set = set(base_keys)
        closed = [i for i, k in enumerate(base_keys) if k not in open_keys]
        opened = [f for f in dropped['faces'] if key(f) not in base_set]
        missing = sorted({f['material'] for f in opened} - set(base['materials']) - {'shell', 'unresolved'})
        if missing: p.error('Dropped faces use materials outside the base set: %s' % missing)
        floors = dict(version=1, shipped_sha256=digest(review_bytes), regions=sorted(FLOORS), closed_face_indices=closed,
                      closed_faces=[base['faces'][i] for i in closed], open_faces=opened)
        props = {q['record']: q for q in json.loads((tmp / 'props/props.json').read_text())['props']}
        pedestal = props[153]
        if (pedestal['template'], pedestal['region'], pedestal['material']) != (33, 197, source['pedestal']['material']): p.error('prop153 differs from the contract pedestal')
        staged = {f['file']: tmp / 'props/sprites' / ('%s_frame_%d.png' % (pedestal['material'], i)) for i, f in enumerate(frames)}
        for f in frames:
            if not staged[f['file']].is_file() or digest(staged[f['file']].read_bytes()) != f['sha256']: p.error(f'{f["file"]} differs from the contract frame hash')
        staged['icon.png'] = tmp / 'icon/icon.png'
        out = a.output_root / PACK; out.mkdir(parents=True)
        for name, path in sorted(staged.items()): shutil.copyfile(path, out / name)
        (out / 'floors.json').write_text(json.dumps(floors, indent=1) + '\n')
    print('PASS museum_long_arm: floors closed %d / open %d, %d frames, icon' % (len(closed), len(opened), len(frames)))


if __name__ == '__main__':
    main()
