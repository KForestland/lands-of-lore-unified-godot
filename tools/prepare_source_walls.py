#!/usr/bin/env python3
"""Append the original's rendered wall records that a geometric review pack lacks, and the Jungle's ceilings.

The Jungle (jungle_review/jungle.json) and Hive (hive_review/hive.json) packs draw boundary walls per wall record but
derive interior walls geometrically (lol2/interior_spans.build: floor/ceiling exposure on reciprocal edges; special
connectors and floor subdivisions deferred). The original renders every wall record its callers accept
(lol2/map_source_walls.export_source_walls replays 0x114584/0x115250/0x11511c/0x114aa4), so full-height dividers on
interior edges (classes 4 and 12), lintels and steps on deferred edges never reached these packs: see-through walls,
a void at the Hive brazier, no collision where the original has a wall.

This tool keeps every existing face index (feature hosts exclude faces by index) and appends:
- one 'wall' face per rendered source wall record the pack does not bind (source_wall true, wall_record, surface_code),
  textured with lol2/map_surfaces.bind_surfaces (the Museum's prepare_museum_source_walls.py recipe); the pack's wall
  faces without a material on the same region edge are retired (retired_static_wall_indices, excluded at load); records
  with byte5 bit 0x10 (codes 16-31, the 0x11511c caller) are left out. The appended walls are drawn, not collision: the
  original's movement is region-based (bit0 blockers) and its wall records never block;
- for L4_HJ only, one 'ceiling' face per region whose native ceiling selector (region word 17, or 16 with word 14 bit 7)
  is not 255 (the rule of prepare_museum_review.py / prepare_hive_review_media.py; the Jungle producer never emitted
  ceilings, so the gorge and tunnels had no roof).
interior_audit.span_start records where the interior spans begin so loaders stop deriving it from the face count.

  python3 tools/prepare_source_walls.py --game GAME --area L4_HJ --pack assets/lol2/generated/jungle_review --out FRESH
--area L8_SJ (darker_jungle/area.json, built from source walls by prepare_darker_jungle_portable.py) is a proof run: it
appends nothing when the pack already binds every rendered record (the integration check for later levels).
Writes FRESH/<pack name>/ (the pack with the appended faces and the new material PNGs) and FRESH/report.json.
"""
import argparse, hashlib, json, shutil, sys, tempfile
from collections import Counter
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path[:0] = [str(TOOLS), str(TOOLS / 'lol2')]
PACK_FILE = {'L4_HJ': 'jungle.json', 'L5_HC': 'hive.json', 'L8_SJ': 'area.json', 'L10_DC': 'area.json', 'L13_RC': 'area.json', 'L16_CA': 'area.json', 'L19_BC': 'area.json', 'L9_DR': 'area.json', 'L12_CM': 'area.json', 'L14_HT': 'area.json', 'L17_HC': 'area.json', 'L20_BB': 'area.json'}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def edge_key(a, b):
    p, q = (round(a[0]), round(a[2])), (round(b[0]), round(b[2]))
    return (p, q) if p <= q else (q, p)


def prepare(game, area, pack, out):
    if out.exists(): raise ValueError('Output must be fresh')
    from lol2 import map_geometry, map_materials, map_source_walls, map_surfaces
    name = PACK_FILE[area]
    data = json.loads((pack / name).read_text())
    # Packs built from source walls directly (L8_SJ area.json: kind 'source_wall' faces) bind by face; the Act 1 Jungle/Hive
    # packs list their bindings.
    bound = {b['wall_record'] for b in data.get('wall_bindings', [])} | {f['wall_record'] for f in data['faces'] if (f.get('kind') == 'source_wall' or f.get('source_wall')) and 'wall_record' in f}
    span_count = int(data.get('interior_audit', {}).get('span_count', 0))
    faces = data['faces']
    with tempfile.TemporaryDirectory(prefix='source-walls-') as temp:
        t = Path(temp)
        map_geometry.export_geometry(game, area, t / 'geometry')
        g = json.loads((t / 'geometry/geometry.json').read_text())
        pack_sha = data.get('source_sha256') or data.get('source', {}).get('sha256')
        if g['source']['sha256'] != pack_sha: raise ValueError('Pack belongs to a different archive')
        native = map_source_walls.export_source_walls(game, area, t / 'geometry', t / 'geometry')
        map_materials.export_materials(game, area, t / 'materials')
        map_surfaces.bind_surfaces(game, area, t / 'geometry', t / 'materials', t)
        review = json.loads((t / 'review.json').read_text())
        regions = g['regions']
        # Missing records: rendered by the original, not bound by the pack.
        missing = [f for f in review['faces'] if f['kind'] == 'source_wall' and f['wall_record'] not in bound]
        # Records with byte5 bit 0x10 (surface codes 16-31) take the 0x11511c caller: the region's own vertices and wall bytes
        # 2/3/4/7, no neighbour, no invented texture position (map_source_walls). Their quads ring the Hive lift platform
        # (regions 775-781) that hive_elevator.gd hosts; they are left out here.
        skipped_special = [f for f in missing if f['surface_code'] >= 16]
        missing = [f for f in missing if f['surface_code'] < 16]
        unresolved = [f for f in missing if f['material'] == 'unresolved']
        missing = [f for f in missing if f['material'] != 'unresolved']
        # Pack wall faces without a material on an edge that gets a source wall: retired.
        missing_edges = {}
        for f in missing:
            r = regions[f['region']]; j = f['edge']
            vi = r['vertex_indices']
            a, b = g['vertices_fixed'][vi[j]], g['vertices_fixed'][vi[(j + 1) % 4]]
            missing_edges.setdefault(edge_key([a[0] / 65536, 0, -a[1] / 65536], [b[0] / 65536, 0, -b[1] / 65536]), []).append(f)
        retired = []
        for i, face in enumerate(faces):
            if face['kind'] != 'wall' or 'material' in face: continue
            if edge_key(face['points'][0], face['points'][1]) in missing_edges: retired.append(i)
        materials = dict(data['materials'])
        cutouts = list(data.get('alpha_cutout_materials', []))
        report = json.loads((t / 'materials/materials.json').read_text())
        available = {str(m['index']): m for m in report['materials']}
        out.mkdir(parents=True)
        shutil.copytree(pack, out / pack.name)
        dest = out / pack.name / 'source_walls'
        dest.mkdir()
        added_materials = {}
        def material_key(k):
            if k in materials: return k
            key = 'sourcewall_' + k
            if key not in materials:
                src = t / review['materials'][k]
                shutil.copy2(src, dest / (k + '.png'))
                materials[key] = 'source_walls/' + k + '.png'
                added_materials[key] = sha(dest / (k + '.png'))
                m = available[k]
                if m.get('alpha_cutout') or m.get('has_alpha'): cutouts.append(key)
            return key
        appended = []
        for f in sorted(missing, key=lambda f: f['wall_record']):
            # bind_surfaces reverses native top-first points; the pack's walls run bottom a, bottom b, top b, top a.
            appended.append(dict(region=f['region'], kind='wall', source_wall=True, edge=f['edge'], surface_code=f['surface_code'],
                                 wall_record=f['wall_record'], material=material_key(f['material']), uv=f['uv'], points=f['points']))
        ceilings = []
        if area == 'L4_HJ':
            for f in review['faces']:
                if f['kind'] == 'ceiling' and f['material'] != 'unresolved':
                    ceilings.append(dict(region=f['region'], kind='ceiling', material=material_key(f['material']), uv=f['uv'], points=f['points']))
        data['faces'] = faces + appended + ceilings
        data['materials'] = materials
        data['alpha_cutout_materials'] = cutouts
        data['retired_static_wall_indices'] = retired
        data.setdefault('interior_audit', {})['span_start'] = len(faces) - span_count
        data['source_walls'] = dict(rendered=len(native['faces']), appended=len(appended), unresolved=[dict(region=f['region'], edge=f['edge'], wall_record=f['wall_record']) for f in unresolved],
                                    skipped_special=[dict(region=f['region'], edge=f['edge'], wall_record=f['wall_record'], surface_code=f['surface_code']) for f in skipped_special],
                                    retired=len(retired), ceilings=len(ceilings),
                                    scope='Original wall records the geometric span builder did not bind (map_source_walls callers), appended after the spans so earlier face indices stay; one-sided toward their region. Ceilings: native ceiling selector regions (L4_HJ).')
        (out / pack.name / name).write_text(json.dumps(data, separators=(',', ':')) + '\n')
        summary = dict(area=area, pack=name, rendered_records=len(native['faces']), pack_bound=len(bound), appended=len(appended),
                       appended_by_code=dict(sorted(Counter(f['surface_code'] for f in appended).items())), unresolved=len(unresolved),
                       retired=len(retired), ceilings=len(ceilings), skipped_special=len(skipped_special), added_materials=added_materials, faces_before=len(faces), faces_after=len(data['faces']),
                       span_start=data['interior_audit']['span_start'], pack_sha256=sha(out / pack.name / name))
        (out / 'report.json').write_text(json.dumps(summary, indent=1) + '\n')
        print(json.dumps(summary))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--area', choices=sorted(PACK_FILE), required=True)
    p.add_argument('--pack', type=Path, required=True, help='existing pack folder (jungle_review or hive_review)')
    p.add_argument('--out', type=Path, required=True, help='fresh output folder')
    a = p.parse_args()
    prepare(a.game.resolve(), a.area, a.pack.resolve(), a.out.resolve())


if __name__ == '__main__':
    main()
