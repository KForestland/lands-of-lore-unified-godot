#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_review pack from explicit original game files.

  python3 tools/prepare_museum_review.py --game GAME --recipe scripts/lol2/museum_review_selection_source.json \
      --layout scripts/lol2/museum_review_capture_layout_source.json --output-root FRESH

The pack is written by the unchanged tools/build_museum_review.py. Its inputs are regenerated from the originals with
published readers instead of the historical museum_geometry/museum_materials/museum_capture exports:
- geometry: lol2/map_geometry.export_geometry(L3_DH);
- presets (region -> preset, name, resource) and the initial surface setup: lol2/map_surfaces.source_tables with the region
  record selector words 16 (floor) / 16|17 (ceiling) and resolve_resource (texture indirection);
- materials: lol2/map_materials.export_materials(L3_DH) restricted to the recorded captured set; raw-variant images in the
  recorded capture orientation (layout recipe), written with lol2_material_format.png_rgb and checked against the captured
  hashes;
- rotation table: lol2_rotation_table.rotation_table;
- arrival: the L3_DH arrival entry that every L1_DC transition to level 3 names (build_game_atlas.commands), at the floor of
  its region.
The selection recipe (shared with prepare_museum_long_arm_media.py) carries the captured material set and the deferred
ceilings. Builder inputs are written under FRESH/tmp/museum_review_inputs and passed as relative paths, so museum.json
'sources' is deterministic. Validated inputs are staged before the builder runs; builder failures may leave partial output. No historical export, RE checkout or native replay.
"""
import argparse, hashlib, json, shutil, struct, subprocess, sys, tempfile
from pathlib import Path

RECIPE_SHA256 = '501ea933b9944ab7cfc893446fef346d142861ee53f96c137865a42b9348b477'  # scripts/lol2/museum_review_selection_source.json
LAYOUT_SHA256 = 'b13904bc9d9cb76e3a5972dc77b88fe95fbf8b1eadc963d3eea42512bec16e5c'  # scripts/lol2/museum_review_capture_layout_source.json
ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac',
             'DAT/L1_DC.MIX': '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'}
PACK = 'assets/lol2/generated/museum_review'
INPUTS = 'tmp/museum_review_inputs'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def prepare_inputs(game, tmp, recipe, layout, ms, rotation_table, png_rgb, arrival_entry):
    """Builder input files in tmp/inputs; returns their names. Raises on any mismatch."""
    from PIL import Image
    src = tmp / 'inputs'; src.mkdir()
    shutil.copyfile(tmp / 'geometry/geometry.json', src / 'geometry.json')
    g = json.loads((src / 'geometry.json').read_text())
    area, raw, presets = ms.source_tables(game, 'L3_DH')
    blob = (tmp / 'materials/texture.bin').read_bytes(); deferred = set(recipe['ceiling_deferred'])
    regions, ceilings = [], []
    for r in g['regions']:
        w = struct.unpack('<22H', bytes.fromhex(r['raw_hex']))
        for sel, dest, ceiling in [(w[16] & 255, regions, False), (w[16 if w[14] & 128 else 17] & 255, ceilings, True)]:
            if sel == 255 or sel >= len(presets) or (ceiling and r['id'] in deferred): continue
            k, _ = ms.resolve_resource(presets[sel]['resource'], blob)
            dest.append(dict(region=r['id'], preset=sel, name=presets[sel]['name'], resource_index=k))
    (src / 'presets.json').write_text(json.dumps(dict(regions=regions, ceiling_regions=ceilings)))
    bits = {2.0: 0, 1.0: 1, 0.5: 2, 0.25: 3}
    (src / 'surface_setup.json').write_text(json.dumps(dict(presets_sha256=digest((src / 'presets.json').read_bytes()), results=[
        dict(preset=x['index'], initial_flags=0, angle_word=x['angle'], offset_x_fixed=x['offset_x'], offset_y_fixed=x['offset_y'],
             offset_bytes=list(x['offsets']), flags=bits[x['scale']] << 14) for x in presets])))
    (src / 'rotation_table.bin').write_bytes(rotation_table(game))
    report = json.loads((tmp / 'materials/materials.json').read_text()); keep = set(recipe['material_indices'])
    assert keep <= {m['index'] for m in report['materials']}, 'captured material set not in the export'
    report['materials'] = [dict(m, **({'review_fps': recipe['review_fps'][str(m['index'])]} if str(m['index']) in recipe['review_fps'] else {}))
                           for m in report['materials'] if m['index'] in keep]
    mats = src / 'materials'; mats.mkdir()
    for m in report['materials']:
        folder = mats / ('material_%04d' % m['index']); shutil.copytree(tmp / 'materials' / folder.name, folder)
        if m['index'] in layout['transposed']:
            assert m.get('source_pixel_layout') == 'column_major_raw', ('layout', m['index'])
            want = layout['captured_sha256'][str(m['index'])]
            for name, expected in [('mip_0_palette.png', want['image'])] + list(zip(m['animation_frames'], want['frames'])):
                im = Image.open(folder / name).convert('RGB').transpose(Image.Transpose.TRANSPOSE)
                data = png_rgb(im.size[0], im.size[1], im.tobytes())
                assert digest(data) == expected, ('captured image', m['index'], name)
                (folder / name).write_bytes(data)
    (mats / 'materials.json').write_text(json.dumps(report))
    region = g['regions'][arrival_entry['region']]
    (src / 'arrival.json').write_text(json.dumps(dict(geometry_sha256=digest((src / 'geometry.json').read_bytes()),
        saves=[dict(native_xy=[float(arrival_entry['x']), float(arrival_entry['y'])], region=arrival_entry['region'], floor_height=region['floor_base'])])))
    return src


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'recipe', 'layout', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    output = a.output_root.resolve()
    for original in [a.game, a.recipe, a.layout]:
        original = original.resolve()
        if output == original or output in original.parents or original in output.parents:
            p.error('--output-root overlaps an input')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    for need in ['build_museum_review.py', 'export_museum_geometry.py']:
        if not (tools / need).is_file(): p.error('Missing builder file ' + str(tools / need))
    for path, want, label in [(a.recipe, RECIPE_SHA256, 'Museum review selection recipe'), (a.layout, LAYOUT_SHA256, 'Museum capture layout recipe')]:
        if not path.is_file(): p.error('Missing input: ' + str(path))
        if digest(path.read_bytes()) != want: p.error(f'{path}: not the pinned {label} ({want})')
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    recipe, layout = json.loads(a.recipe.read_text()), json.loads(a.layout.read_text())
    import map_geometry, map_materials, map_surfaces
    from lol2_rotation_table import rotation_table
    from lol2_material_format import png_rgb
    from verify_actor_item_grants import source_area
    from build_game_atlas import commands
    with tempfile.TemporaryDirectory(prefix='museum-review-') as tmp:
        tmp = Path(tmp)
        try:
            _, _, item, cave, _, _ = source_area('L1_DC', game=a.game)
            entries = {t['destination_entry'] for t in commands(cave, item)[1] if t['destination_level'] == 3}
            assert len(entries) == 1, ('Cave -> Museum entries', entries)
            map_geometry.export_geometry(a.game, 'L3_DH', tmp / 'geometry')
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            arrivals = json.loads((tmp / 'geometry/arrivals.json').read_text())['entries']
            entry = next(e for e in arrivals if e['selector'] == next(iter(entries)))
            src = prepare_inputs(a.game, tmp, recipe, layout, map_surfaces, rotation_table, png_rgb, entry)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, TypeError) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
        a.output_root.mkdir(parents=True); shutil.copytree(src, a.output_root / INPUTS)
    names = dict(geometry='geometry.json', presets='presets.json', materials='materials', arrival='arrival.json', **{'surface-setup': 'surface_setup.json'},
                 **{'rotation-table': 'rotation_table.bin'})
    args = [sys.executable, '-B', str(tools / 'build_museum_review.py'), '--game-root', str(a.game.resolve())]
    for flag, name in names.items(): args += ['--' + flag, f'{INPUTS}/{name}']
    args += ['--out', PACK]
    run = subprocess.run(args, cwd=a.output_root, capture_output=True, text=True)
    if run.returncode: p.error('build_museum_review.py failed: ' + run.stderr.strip()[-300:])
    print('PASS museum_review:', run.stdout.strip())


if __name__ == '__main__':
    main()
