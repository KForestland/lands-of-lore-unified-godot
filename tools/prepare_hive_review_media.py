#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/hive_review pack (hive.json, material_K.png, material_K_frame_I.png) from
explicit original game files and one minimal capture recipe.

  python3 tools/prepare_hive_review_media.py --game GAME --recipe scripts/lol2/hive_review_capture_source.json \
      --output-root FRESH

prepare_hive_review.py (unchanged) reads seven historical exports. This tool keeps its face/UV/wall/interior logic
unchanged and regenerates every input from the originals with published helpers:
- geometry and arrival records: lol2/map_geometry.export_geometry(L5_HC);
- floor/ceiling presets, initial surface setup and texture indirection: lol2/map_surfaces.source_tables /
  resolve_resource with the region selector words 16 (floor) / 16|17 (ceiling), ceilings only for standalone ceilings;
- materials: lol2/map_materials.export_materials(L5_HC) (texture.bin = the pinned Hive blob);
- rotation table: lol2_rotation_table.rotation_table;
- interior spans: lol2/interior_spans.build;
- arrivals: the L5_HC entries named by the L4_HJ -> level 5 transitions (verify_actor_item_grants.source_area,
  build_game_atlas.commands).
The recipe holds only recorded choices: the capture's raw-file-order layout of column_major_raw materials (checked
against the captured hashes), the authored review fps and review start heights, and the native ceiling-selector
deferrals of the historical presets. The output root must be fresh and must not equal, contain or lie inside an input.
Nothing is written until every check passes. No historical export, RE checkout, constructor replay or capstone.
"""
import argparse, hashlib, json, math, struct, sys, tempfile
from pathlib import Path

RECIPE_SHA256 = '53a3e7b5cdfa61dcd9c99e9bf95659b4a83ae24af94b6a5c30275452321a9d9d'  # scripts/lol2/hive_review_capture_source.json
ORIGINALS = {'DAT/L5_HC.MIX': 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8',
             'DAT/L4_HJ.MIX': '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f',
             'LOLG.DAT': 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'}
GEOMETRY_KEY = 3776990464
HIVE_BLOB_SHA = 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
PACK = 'assets/lol2/generated/hive_review'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def build_review(g, pres, setup, indirect_records, available, table_bytes, raw, interior_build):
    """prepare_hive_review.py face, UV, wall and interior-span logic, unchanged; inputs passed explicitly."""
    indirect = {r['reference']: r['resource'] for r in indirect_records}
    bindings = {r['region']: r for r in pres['regions']}
    ceiling_bindings = {r['region']: r for r in pres['ceiling_regions']}
    states = {r['preset']: r for r in setup['results'] if r['initial_flags'] == 0}
    table = struct.unpack('<4096i', table_bytes)

    def u32(d, o): return struct.unpack_from('<I', d, o)[0]

    def trig(angle):
        angle &= 65535
        return table[(angle & 32767) >> 3] * (-1 if angle >= 32768 else 1)

    def surface(r, kind='floor'):
        binding = (bindings if kind == 'floor' else ceiling_bindings).get(r['id'])
        if not binding: return {}
        k = indirect.get(binding['resource_index'], binding['resource_index'])
        if k not in available: return {}
        st = states[binding['preset']]; m = available[k]
        aa, bb = trig(st['angle_word']), trig(st['angle_word'] + 16384)
        scale = [2., 1., .5, .25][(st['flags'] >> 14) & 3]; uv = []
        for i in r['vertex_indices']:
            x, y = g['vertices_fixed'][i]; x -= st['offset_x_fixed']; y -= st['offset_y_fixed']
            u = (((y * bb) >> 16) + ((x * aa) >> 16)) * scale / 65536 + st['offset_bytes'][0]
            vv = (((x * bb) >> 16) - ((y * aa) >> 16)) * scale / 65536 + st['offset_bytes'][1]
            uv.append([u / m['width'], vv / m['height']])
        return dict(material=str(k), uv=uv)
    wall_start, wall_count = u32(raw, 8), u32(raw, 0x54)
    assert wall_start + wall_count * 8 == u32(raw, 12), 'wall table'
    wall_bindings = []; wall_unresolved = []

    def wall_surface(r, edge, code, pts):
        words = struct.unpack('<22H', bytes.fromhex(r['raw_hex']))
        first, count = words[13], words[15] & 255
        assert count == 0 or first + count <= wall_count, 'wall records'
        candidates = []
        for i in range(first, first + count):
            d = raw[wall_start + i * 8:wall_start + (i + 1) * 8]
            if d[5] & 31 == code: candidates.append((i, indirect.get(struct.unpack_from('<h', d)[0], struct.unpack_from('<h', d)[0]), d))
        reason = ('missing_record' if not candidates else 'ambiguous_records') if len(candidates) != 1 else ('negative_resource' if candidates[0][1] < 0 else 'unsupported_resource')
        if len(candidates) != 1 or candidates[0][1] not in available:
            wall_unresolved.append(dict(region=r['id'], edge=edge, code=code, reason=reason, candidates=[dict(wall_record=i, resource=k, raw_hex=d.hex()) for i, k, d in candidates]))
            return {}
        i, k, d = candidates[0]; m = available[k]
        top = [pts[3], pts[2], pts[1], pts[0]]
        length = math.dist(top[0][::2], top[1][::2]); height = max(p[1] for p in top) - min(p[1] for p in top)
        if length <= 0 or height <= 0:
            wall_unresolved.append(dict(region=r['id'], edge=edge, code=code, reason='degenerate_span', candidates=[dict(wall_record=i, resource=k, raw_hex=d.hex())]))
            return {}
        mode = (d[6] >> 5) & 3; anchor, other = [(0, 1), (1, 0), (3, 2), (2, 3)][mode]
        origin = list(top[anchor]); end = top[other]
        origin[1] = max(p[1] for p in top) if mode < 2 else min(p[1] for p in top)
        scale = [2., 1., .5, .25][d[7] & 3]; addressing = 8 if d[6] & 16 else (16 if d[6] & 8 else 0)
        w, h = m['width'], m['height']; dx, dz = (end[0] - origin[0]) / length, (end[2] - origin[2]) / length
        uscale = scale if addressing else w / length; vscale = scale if addressing == 8 else h / height
        uv = [[(((p[0] - origin[0]) * dx + (p[2] - origin[2]) * dz) * uscale + (d[2] if addressing else 0)) / w, ((p[1] - origin[1]) * (-1 if mode < 2 else 1) * vscale + (d[3] if addressing == 8 else 0)) / h] for p in pts]
        assert all(math.isfinite(c) for p in uv for c in p), 'finite wall uv'
        wall_bindings.append(dict(region=r['id'], edge=edge, code=code, wall_record=i, resource=k, raw_hex=d.hex()))
        return dict(material=str(k), uv=uv)
    v = g['vertices_fixed']; faces = []

    def point(i, h): return [v[i][0] / 65536, h, -v[i][1] / 65536]
    for r in g['regions']:
        for kind, heights in [('floor', r['floor_corners']), ('ceiling', r['ceiling_corners'])]:
            if heights is None: continue
            faces.append(dict(region=r['id'], kind=kind, **surface(r, kind), points=[point(i, h) for i, h in zip(r['vertex_indices'], heights)]))
        if not r.get('standalone_walls', True): continue
        for j, n in enumerate(r['neighbors']):
            if n is not None: continue
            k = (j + 1) % 4
            pts = [point(r['vertex_indices'][j], r['floor_corners'][j]), point(r['vertex_indices'][k], r['floor_corners'][k]), point(r['vertex_indices'][k], r['ceiling_corners'][k]), point(r['vertex_indices'][j], r['ceiling_corners'][j])]
            faces.append(dict(region=r['id'], kind='wall', points=pts, **wall_surface(r, j, j | 4, pts)))
    spans, audit = interior_build(g)
    for span in spans:
        pts = [[c * 64 for c in p] for p in span['points']]; r = g['regions'][span['region']]
        faces.append(dict(region=span['region'], kind='wall', points=pts, **wall_surface(r, span['edge'], span['edge'] | (8 if span['exposure']['kind'] == 'step' else 0), pts)))
    return faces, wall_bindings, wall_unresolved, audit


def file_order(png_path, png_rgb, Image):
    """Captured layout of a column_major_raw source: the raw column-major bytes read as rows of the same width."""
    im = Image.open(png_path).convert('RGB'); w, h = im.size; data = im.tobytes()
    raw = b''.join(data[(y * w + x) * 3:(y * w + x) * 3 + 3] for x in range(w) for y in range(h))
    return png_rgb(w, h, raw)


def prepare(game, tmp, recipe, h):
    h.map_geometry.export_geometry(game, 'L5_HC', tmp / 'geometry')
    h.map_materials.export_materials(game, 'L5_HC', tmp / 'materials')
    geometry_bytes = (tmp / 'geometry/geometry.json').read_bytes(); g = json.loads(geometry_bytes)
    blob = (tmp / 'materials/texture.bin').read_bytes(); assert digest(blob) == HIVE_BLOB_SHA, 'Hive texture blob'
    archive = (game / 'DAT/L5_HC.MIX').read_bytes()
    entry = next(e for e in h.parse_mix(archive) if e['key'] == GEOMETRY_KEY); raw = archive[entry['offset']:entry['offset'] + entry['size']]
    assert g['source']['sha256'] == ORIGINALS['DAT/L5_HC.MIX'] and g['source']['entry_sha256'] == digest(raw), 'geometry source'

    # Presets, setup and indirection from the source tables.
    _, _, presets = h.map_surfaces.source_tables(game, 'L5_HC')
    deferred = set(recipe['ceiling_deferred_primary']); regions, ceilings, changed = [], [], set()
    for r in g['regions']:
        w = struct.unpack('<22H', bytes.fromhex(r['raw_hex']))
        fs, cs = w[16] & 255, w[16 if w[14] & 128 else 17] & 255
        if fs != 255 and fs < len(presets):
            regions.append(dict(region=r['id'], preset=fs, name=presets[fs]['name'], resource_index=presets[fs]['resource']))
        if cs != 255 and cs < len(presets) and r.get('standalone_ceiling'):
            if r['id'] in deferred: changed.add(r['id']); continue
            ceilings.append(dict(region=r['id'], preset=cs, name=presets[cs]['name'], resource_index=presets[cs]['resource']))
    assert changed == {265}, ('recorded ceiling deferrals that change a binding', sorted(changed))
    assert all(g['regions'][i]['record_role'] == 'primary_region' and g['regions'][i]['standalone_ceiling'] for i in deferred), 'deferred regions'
    bits = {2.0: 0, 1.0: 1, 0.5: 2, 0.25: 3}
    setup = dict(results=[dict(preset=x['index'], initial_flags=0, angle_word=x['angle'], offset_x_fixed=x['offset_x'],
                               offset_y_fixed=x['offset_y'], offset_bytes=list(x['offsets']), flags=bits[x['scale']] << 14) for x in presets])
    wall_start, wall_count = struct.unpack_from('<II', raw, 8)[0], struct.unpack_from('<I', raw, 0x54)[0]
    references = {p['resource'] for p in presets} | {struct.unpack_from('<h', raw, wall_start + i * 8)[0] for i in range(wall_count)}
    indirection = [dict(reference=x, resource=h.map_surfaces.resolve_resource(x, blob)[0]) for x in sorted(x for x in references if x < 0)]

    report = json.loads((tmp / 'materials/materials.json').read_text())
    available = {m['index']: m for m in report['materials']}
    for k, fps in recipe['review_fps'].items(): available[int(k)] = dict(available[int(k)], review_fps=fps)
    faces, wall_bindings, wall_unresolved, audit = build_review(
        g, dict(regions=regions, ceiling_regions=ceilings), setup, indirection, available, h.rotation_table(game), raw, h.interior_build)

    # Arrivals named by the Jungle -> Hive transitions.
    _, _, item, jungle, _, _ = h.source_area('L4_HJ', game=game)
    named = sorted({t['destination_entry'] for t in h.commands(jungle, item)[1] if t['destination_level'] == 5})
    assert named == [1, 2], ('Jungle -> Hive entries', named)
    arrivals = []
    for e in json.loads((tmp / 'geometry/arrivals.json').read_text())['entries']:
        if e['selector'] not in named: continue
        region = g['regions'][e['region']]; height = recipe['review_start_heights'][str(e['selector'])]
        assert height == max(region['floor_corners']) + 34, ('recorded review height', e['selector'])
        record = archive[e['archive_offset']:e['archive_offset'] + 12]
        assert struct.unpack_from('<hhH', record) == (e['x'], e['y'], e['heading_units']), 'arrival record'
        arrivals.append(dict(entry=e['selector'], region=e['region'], godot_xz=[e['x'], -e['y']], heading_units=e['heading_units'],
                             raw_hex=record.hex(), source_offset=e['archive_offset'], review_start=[e['x'], height, -e['y']]))

    files, materials, animations = {}, {}, {}
    for k in sorted({f['material'] for f in faces if 'material' in f}):
        m = available[int(k)]; folder = tmp / 'materials' / f'material_{int(k):04d}'
        sources = [('material_%s.png' % k, 'mip_0_palette.png')] + [(f'material_{k}_frame_{i}.png', s) for i, s in enumerate(m.get('animation_frames') or [])]
        layout = recipe['file_order_raw_materials'].get(k)
        assert (layout is not None) == (m.get('source_pixel_layout') == 'column_major_raw'), ('raw layout', k)
        for i, (name, source) in enumerate(sources):
            data = file_order(folder / source, h.png_rgb, h.Image) if layout else (folder / source).read_bytes()
            if layout: assert digest(data) == ([layout['image']] + layout['frames'])[i], ('captured image', k, name)
            files[name] = data
        if layout: assert len(layout['frames']) == len(sources) - 1, ('captured frames', k)
        materials[k] = 'material_%s.png' % k
        if m.get('animation_frames'):
            animations[k] = dict(frames=[n for n, _ in sources[1:]], fps=m['review_fps'])
    assert set(animations) == set(recipe['review_fps']), 'review fps set'
    hive = dict(materials=materials, animations=animations, wall_bindings=wall_bindings, wall_unresolved=wall_unresolved,
                faces=faces, start=arrivals[0]['review_start'], arrivals=arrivals, source_sha256=g['source']['sha256'],
                geometry_sha256=digest(geometry_bytes), interior_audit=audit)
    files['hive.json'] = json.dumps(hive).encode()
    return files, hive


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'recipe', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for source in [a.game, a.recipe.parent]:
        if overlaps(a.output_root, source): p.error(f'--output-root overlaps input {source}')
    if not a.recipe.is_file(): p.error('Missing input: ' + str(a.recipe))
    if digest(a.recipe.read_bytes()) != RECIPE_SHA256: p.error(f'{a.recipe}: not the pinned Hive review capture recipe ({RECIPE_SHA256})')
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    try:
        from types import SimpleNamespace
        import map_geometry, map_materials, map_surfaces
        from interior_spans import build as interior_build
        from lol2_rotation_table import rotation_table
        from lol2_material_format import png_rgb
        from lol2_source_format import parse_mix
        from verify_actor_item_grants import source_area
        from build_game_atlas import commands
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    h = SimpleNamespace(map_geometry=map_geometry, map_materials=map_materials, map_surfaces=map_surfaces, interior_build=interior_build,
                        rotation_table=rotation_table, png_rgb=png_rgb, parse_mix=parse_mix, source_area=source_area, commands=commands, Image=Image)
    recipe = json.loads(a.recipe.read_text())
    with tempfile.TemporaryDirectory(prefix='hive-review-') as tmp:
        try:
            files, hive = prepare(a.game, Path(tmp), recipe, h)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, TypeError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    out = a.output_root / PACK; out.mkdir(parents=True)
    for name, data in sorted(files.items()): (out / name).write_bytes(data)
    print('PASS hive_review: faces', len(hive['faces']), 'materials', len(hive['materials']), 'animations', sorted(hive['animations']),
          'wall bindings', len(hive['wall_bindings']), 'unresolved', len(hive['wall_unresolved']), 'files', len(files))


if __name__ == '__main__':
    main()
