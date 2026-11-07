#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/hive_boulders pack (boulders.json) and the legacy staging check record
docs/hive-boulder-staging-checks.json from explicit original game files.

  python3 tools/prepare_hive_boulders_media.py --game GAME --recipe scripts/lol2/hive_review_capture_source.json \
      --output-root FRESH

prepare_hive_boulders.py (unchanged) reads the historical hive_geometry_20260914/geometry.json and the shipped
hive_review/hive.json, and runs prepare_hive_review.py through runpy (which rewrites hive_review from historical inputs)
to borrow its wall resolver. This tool instead:
- prepares the Hive base in memory with prepare_hive_review_media.prepare (fresh geometry, presets, materials,
  arrivals; nothing written), and takes the staged floor/ceiling faces from that fresh hive.json;
- resolves every boulder-region edge style with the base's own unchanged wall_surface, driven through
  prepare_hive_review_media.build_review with one synthetic span per (region, edge, code) on the same dummy quad as the
  legacy writer, so the original wall record, material and addressing bytes are those the base resolves;
- reads the path, markers, actors and regions from the original L5_HC geometry and the fresh geometry export.
The legacy logic and output layout are otherwise unchanged. The output root must be fresh and must not equal, contain
or lie inside an input. Nothing is written until every check passes. No historical export, RE checkout or runpy.
"""
import argparse, hashlib, json, struct, sys, tempfile
from pathlib import Path

ARCHIVE_SHA = 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
GEOMETRY_KEY = 3776990464
PACK = 'assets/lol2/generated/hive_boulders'
CHECKS = 'docs/hive-boulder-staging-checks.json'


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def resolver(base, game, g, tmp, raw, h):
    """The base wall_surface over the fresh inputs: returns resolve(region, edge, code, pts) -> (style, binding)."""
    blob = (tmp / 'materials/texture.bin').read_bytes()
    available = {m['index']: m for m in json.loads((tmp / 'materials/materials.json').read_text())['materials']}
    _, _, presets = h.map_surfaces.source_tables(game, 'L5_HC')
    wall_start, wall_count = struct.unpack_from('<I', raw, 8)[0], struct.unpack_from('<I', raw, 0x54)[0]
    references = {p['resource'] for p in presets} | {struct.unpack_from('<h', raw, wall_start + i * 8)[0] for i in range(wall_count)}
    indirection = [dict(reference=x, resource=h.map_surfaces.resolve_resource(x, blob)[0]) for x in sorted(x for x in references if x < 0)]
    # Regions keep their raw records; no floor/ceiling/closed-wall faces are generated, only the given spans.
    quiet = dict(g, regions=[dict(r, floor_corners=None, ceiling_corners=None, standalone_walls=False) for r in g['regions']])

    def resolve(requests):
        spans = [dict(region=region, edge=code, points=[[c / 64 for c in p] for p in pts], exposure=dict(kind='none'))
                 for region, edge, code, pts in requests]
        faces, bindings, _, _ = base.build_review(quiet, dict(regions=[], ceiling_regions=[]), dict(results=[]), indirection,
                                                  available, h.rotation_table(game), raw, lambda _: (spans, None))
        assert len(faces) == len(requests), 'one face per request'
        it = iter(bindings); out = []
        for face, (region, edge, code, _) in zip(faces, requests):
            if 'material' not in face: out.append((None, None)); continue
            b = next(it); assert (b['region'], b['code']) == (region, code), 'binding order'
            out.append((face, b))
        assert next(it, None) is None, 'unconsumed bindings'
        return out
    return resolve, available


def build(game, tmp, recipe, base, h):
    files, hive = base.prepare(game, tmp, recipe, h)
    arc = (game / 'DAT/L5_HC.MIX').read_bytes(); assert hashlib.sha256(arc).hexdigest() == ARCHIVE_SHA, 'archive'
    e = next(e for e in h.parse_mix(arc) if e['key'] == GEOMETRY_KEY); geo = arc[e['offset']:e['offset'] + e['size']]
    source = json.loads((tmp / 'geometry/geometry.json').read_text()); staged = hive
    # prepare_hive_boulders.py main(), unchanged apart from inputs and the resolver call.
    _, _, paths = h.section(geo, 0xdc, 0xd8, 4); _, _, markers = h.section(geo, 0xc8, 0xc4, 8); first, count, flags = struct.unpack_from('<HBB', paths, 4); assert (first, count, flags) == (11, 13, 0), 'path'
    points = []
    for n in range(first, first + count):
        x, z, region, fl = struct.unpack_from('<hhHH', markers, n * 8); assert region in [1217, 1218], 'marker region'; points.append(dict(position=[x, -z], region=region, flags=fl))
    surfaces = []
    for region, kind in [(794, 'ceiling'), (1216, 'floor'), (1217, 'floor'), (1218, 'floor'), (801, 'ceiling')]:
        faces = [f for f in staged['faces'] if int(f['region']) == region and f['kind'] == kind]; assert faces, (region, kind)
        r = source['regions'][region]; height = r[kind + '_base']; assert [p[1] for p in faces[0]['points']] == r[kind + '_corners'], 'surface corners'
        surfaces.append(dict(region=region, kind=kind, height=height, faces=faces))
    r = source['regions'][1216]; trigger = dict(region=1216, floor=r['floor_base'], ceiling=r['ceiling_base'], polygon=[[source['vertices_fixed'][v][0] / 65536, -source['vertices_fixed'][v][1] / 65536] for v in r['vertex_indices']])
    _, _, actors = h.section(geo, 0x1c, 0x68, 56); spawns = {}
    for actor in [30, 31]:
        raw = actors[actor * 56:(actor + 1) * 56]; x, z, heading, y = struct.unpack_from('<hhHh', raw); spawns[str(actor)] = [x, y, -z]
    resolve, available = resolver(base, game, source, tmp, geo, h)
    changed = {794, 801, 1216, 1217, 1218}
    wall_regions = changed | {n for i in changed for n in source['regions'][i]['neighbors'] if n is not None}
    edges, requests = [], []
    for region in sorted(wall_regions):
        r = source['regions'][region]
        assert r['record_role'] == 'primary_region' and not r['floor_subdivisions'] and not r['flags'] & 0x10, ('wall region', region)
        for edge, neighbor in enumerate(r['neighbors']):
            ia = [edge, (edge + 1) % 4]; ids = [r['vertex_indices'][i] for i in ia]
            row = dict(region=region, edge=edge, neighbor=neighbor, points=[[source['vertices_fixed'][v][0] / 65536, -source['vertices_fixed'][v][1] / 65536] for v in ids], floor=[r['floor_corners'][i] for i in ia], ceiling=[r['ceiling_corners'][i] for i in ia], styles={})
            if neighbor is not None:
                b = source['regions'][neighbor]; assert b['record_role'] == 'primary_region' and not b['floor_subdivisions'] and not b['flags'] & 0x10, ('neighbor', neighbor)
                reciprocal = [j for j in range(4) if set(ids) == set([b['vertex_indices'][j], b['vertex_indices'][(j + 1) % 4]]) and b['neighbors'][j] == region]
                assert len(reciprocal) == 1, (region, neighbor)
                ib = [b['vertex_indices'].index(v) for v in ids]
                row.update(neighbor_floor=[b['floor_corners'][i] for i in ib], neighbor_ceiling=[b['ceiling_corners'][i] for i in ib])
            for kind, code in ([('closed', edge | 4)] if neighbor is None else [('step', edge | 8), ('upper', edge)]):
                # A nondegenerate dummy quad resolves the original record even when the initial span is empty.
                a, b = row['points']; pts = [[a[0], 0, a[1]], [b[0], 0, b[1]], [b[0], 1, b[1]], [a[0], 1, a[1]]]
                requests.append((row, kind, region, edge, code, pts))
            edges.append(row)
    for (row, kind, *_), (style, binding) in zip(requests, resolve([q[2:] for q in requests])):
        if style:
            material = available[int(style['material'])]
            row['styles'][kind] = dict(material=style['material'], raw=list(bytes.fromhex(binding['raw_hex'])), width=material['width'], height=material['height'])
    data = dict(version=1, wall_regions=sorted(wall_regions), edges=edges, archive_sha256=ARCHIVE_SHA, path=dict(first=first, count=count, flags=flags, points=points), surfaces=surfaces, trigger=trigger, spawns=spawns, scope='Original staged floor/ceiling quads and pinned source path/positions. Runtime surface rebuilding, vertical anchoring and clocks remain integration concerns; no collision/event semantics inferred.')
    return {PACK + '/boulders.json': json.dumps(data, indent=2) + '\n',
            CHECKS: json.dumps({k: v for k, v in data.items() if k not in ['surfaces', 'edges']}, indent=2) + '\n'}, data


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'recipe', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for source in [a.game, a.recipe.parent]:
        if overlaps(a.output_root, source): p.error(f'--output-root overlaps input {source}')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    try:
        import prepare_hive_review_media as base
        from types import SimpleNamespace
        import map_geometry, map_materials, map_surfaces
        from interior_spans import build as interior_build
        from lol2_rotation_table import rotation_table
        from lol2_material_format import png_rgb
        from lol2_source_format import parse_mix
        from verify_actor_item_grants import source_area
        from build_game_atlas import commands, section
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    # The base tool's own input checks: recipe pin and pinned originals.
    if not a.recipe.is_file(): p.error('Missing input: ' + str(a.recipe))
    if base.digest(a.recipe.read_bytes()) != base.RECIPE_SHA256: p.error(f'{a.recipe}: not the pinned Hive review capture recipe ({base.RECIPE_SHA256})')
    for rel, want in base.ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if base.digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    h = SimpleNamespace(map_geometry=map_geometry, map_materials=map_materials, map_surfaces=map_surfaces, interior_build=interior_build,
                        rotation_table=rotation_table, png_rgb=png_rgb, parse_mix=parse_mix, source_area=source_area, commands=commands,
                        section=section, Image=Image)
    recipe = json.loads(a.recipe.read_text())
    with tempfile.TemporaryDirectory(prefix='hive-boulders-') as tmp:
        try:
            files, data = build(a.game, Path(tmp), recipe, base, h)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, TypeError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    for rel, text in files.items():
        (a.output_root / rel).parent.mkdir(parents=True, exist_ok=True); (a.output_root / rel).write_text(text)
    print('PASS hive_boulders: surfaces', len(data['surfaces']), 'path markers', data['path']['count'], 'spawns', sorted(data['spawns']),
          'edges', len(data['edges']), 'styled', sum(len(e['styles']) for e in data['edges']))


if __name__ == '__main__':
    main()
