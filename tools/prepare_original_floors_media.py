#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/original_floors pack (floors.json, interior_audit.json, material_N.png,
traversal_fixtures.json, traversal_expanded.json, connected_walk.json, connected_walk_audit.json, full_walk.json,
full_walk_audit.json) from explicit original game files.

  python3 tools/prepare_original_floors_media.py --game GAME --output-root FRESH

The published lol2/import_original_floors.py, build_traversal_fixtures.py (default and --all), build_connected_walk.py
and build_full_walk.py (all unchanged) read the historical draracle_openings/floor_bindings/floor_setup/materials/
floor_variants/rotation_table exports of 2026-09-11. This tool runs their logic unchanged, in that order, on inputs
regenerated from the originals with published helpers:
- geometry: lol2/map_geometry.export_geometry(L1_DC) (every field the builders and interior_spans read is equal);
- floor bindings: lol2/map_surfaces.source_tables with the region selector word 16; positive preset resources only:
  the historical binder left the negative (animation-table) reference of preset 16 'Lava' unresolved, so it stays
  unresolved here (checked: exactly the preset-16 regions);
- initial surface setup: source_tables angle, offsets, scale (flags bits 14-15);
- materials: lol2/map_materials.export_materials(L1_DC) mip 0. The 2026-09-11 capture stored every image in raw
  column-major file order, which is the transpose of the published row-major export; the import's byte-order
  reinterpretation is applied to that captured order;
- rotation table: lol2_rotation_table.rotation_table; interior spans: lol2/interior_spans.build.
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
builder has run. No historical export, RE checkout, constructor replay or capstone.
"""
import argparse, hashlib, io, json, math, struct, sys, tempfile
from collections import defaultdict, Counter
from pathlib import Path

ORIGINALS = {'DAT/L1_DC.MIX': '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345',
             'LOLG.DAT': 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'}
CAVE_BLOB_SHA = '102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'
ROTATION_TABLE_SHA = 'd7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'
UNRESOLVED_PRESETS = {16}  # negative resource reference; historical status 'animation table unresolved'
PACK = 'assets/lol2/generated/original_floors'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def import_floors(g, bindings, setup, table_bytes, captured, build, Image, files):
    """import_original_floors.py main(), unchanged apart from in-memory inputs/outputs.
    captured[descriptor] = PIL image in the historical captured byte order, or absent."""
    states = {r['preset']: r for r in setup['results'] if r['initial_flags'] == 0}; byregion = {r['region']: r for r in bindings['regions']}; table = struct.unpack('<4096i', table_bytes)

    def trig(a):
        a &= 65535; return table[(a & 32767) >> 3] * (-1 if a >= 32768 else 1)
    materials = {}; faces = []; textured = 0
    for r in g['regions']:
        if r.get('floor_subdivisions'): continue
        binding = byregion.get(r['id']); descriptor = binding.get('descriptor_index') if binding else None
        if descriptor is not None and str(descriptor) not in materials:
            if descriptor in captured:
                src = captured[descriptor].convert('RGB'); w, h = src.size
                # Preserve byte order but show native candidate address U*height+V.
                dst = Image.frombytes('RGB', (h, w), src.tobytes()); name = f'material_{descriptor}.png'
                stream = io.BytesIO(); dst.save(stream, format='PNG'); files[name] = stream.getvalue(); materials[str(descriptor)] = dict(path=name, width=w, height=h)
        points = []; uv = []
        for v, z in zip(r['vertex_indices'], r['floor_corners']):
            x, y = g['vertices_fixed'][v]; points.append([x / 65536 / 64, z / 64, -y / 65536 / 64])
            if descriptor is not None and str(descriptor) in materials:
                st = states[binding['preset']]; xx = x - st['offset_x_fixed']; yy = y - st['offset_y_fixed']; aa = trig(st['angle_word']); bb = trig(st['angle_word'] + 16384); u = ((yy * bb) >> 16) + ((xx * aa) >> 16); vv = ((xx * bb) >> 16) - ((yy * aa) >> 16); mode = st['object_flags_3e'] & 0xc000; scale = {0: 2, 0x4000: 1, 0x8000: .5, 0xc000: .25}[mode]; u = u * scale / 65536 + st['object_bytes_30_31'][0]; vv = vv * scale / 65536 + st['object_bytes_30_31'][1]; m = materials[str(descriptor)]; uv.append([vv / m['height'], u / m['width']])
            else: uv.append([0, 0])
        available = descriptor is not None and str(descriptor) in materials; textured += available; faces.append(dict(region=r['id'], material=str(descriptor) if available else 'unresolved', points=points, uv=uv))
    shell = []

    def point(vertex, height):
        x, y = g['vertices_fixed'][vertex]; return [x / 65536 / 64, height / 64, -y / 65536 / 64]
    for r in g['regions']:
        if r.get('standalone_ceiling'):
            shell.append(dict(kind='ceiling', region=r['id'], points=[point(v, h) for v, h in zip(r['vertex_indices'], r['ceiling_corners'])]))
        if not r.get('standalone_walls'): continue
        for edge, neighbor in enumerate(r['neighbors']):
            if neighbor is not None: continue
            j = (edge + 1) % 4; v0, v1 = r['vertex_indices'][edge], r['vertex_indices'][j]
            shell.append(dict(kind='boundary', region=r['id'], edge=edge, points=[point(v0, r['floor_corners'][edge]), point(v1, r['floor_corners'][j]), point(v1, r['ceiling_corners'][j]), point(v0, r['ceiling_corners'][edge])]))
    interior, audit = build(g); shell.extend(interior)
    files['interior_audit.json'] = (json.dumps(audit, indent=2) + "\n").encode()
    result = dict(interior_audit=audit, shell=shell, faces=faces, materials=materials, summary=dict(floor_quads=len(faces), with_texture_candidates=textured, unresolved=len(faces) - textured, ceilings=sum(x["kind"] == "ceiling" for x in shell), boundary_quads=sum(x["kind"] == "boundary" for x in shell), interior_candidates=len(interior)), scope='Original geometry and static material identities. Diagnostic planar UVs, storage-axis interpretation, first variant and 1/64 display scale are provisional. Neutral primary ceilings and absent-neighbor boundary spans only. Interior steps/jambs unresolved. No collision completeness or guest-render parity.')
    files['floors.json'] = (json.dumps(result) + '\n').encode()


def traversal(g, data, expanded, files):
    """build_traversal_fixtures.py, unchanged; expanded = '--all'."""
    f = {int(x['region']): x for x in data['faces']}
    out = []; counts = {'flat': 0, 'slope': 0}
    for a in g['regions']:
        for edge, n in enumerate(a['neighbors']):
            if n is None or n <= a['id']: continue
            b = g['regions'][n]
            if any(r.get('record_role') != 'primary_region' or r.get('floor_subdivisions') or r['flags'] & 0x10 for r in (a, b)): continue
            ids = [a['vertex_indices'][edge], a['vertex_indices'][(edge + 1) % 4]]
            matches = [j for j in range(4) if set(ids) == set([b['vertex_indices'][j], b['vertex_indices'][(j + 1) % 4]]) and b['neighbors'][j] == a['id']]
            if len(matches) != 1: continue
            if any(abs(a['floor_corners'][a['vertex_indices'].index(v)] - b['floor_corners'][b['vertex_indices'].index(v)]) > 1e-6 for v in ids): continue
            faces = [[[v * 64 for v in p] for p in f[r['id']]['points']] for r in (a, b)]
            p, q = [faces[0][a['vertex_indices'].index(v)] for v in ids]
            if math.dist(p, q) < 128: continue
            mid = [(x + y) / 2 for x, y in zip(p, q)]
            ends = []
            for face in faces:
                center = [sum(p[i] for p in face) / 4 for i in range(3)]
                dist = math.hypot(center[0] - mid[0], center[2] - mid[2])
                if dist < 48: break
                ends.append([mid[i] + (center[i] - mid[i]) * 32 / dist for i in range(3)])
            if len(ends) != 2: continue
            kind = 'flat' if all(max(p[1] for p in face) - min(p[1] for p in face) < 1e-6 for face in faces) else 'slope'
            if not expanded and counts[kind] >= 3: continue
            counts[kind] += 1
            local = lambda p: [p[i] - mid[i] for i in range(3)]
            out.append(dict(regions=[a['id'], n], kind=kind, faces=[[local(p) for p in face] for face in faces], shell=[[local([v * 64 for v in p]) for p in face['points']] for face in data['shell'] if int(face['region']) in (a['id'], n)], start=local(ends[0]), end=local(ends[1])))
        if not expanded and all(v == 3 for v in counts.values()): break
    assert all(v >= 3 for v in counts.values()), counts
    files['traversal_expanded.json' if expanded else 'traversal_fixtures.json'] = json.dumps(out, indent=2).encode()


def connected_walk(g, data, pairs, files):
    """build_connected_walk.py, unchanged."""
    faces = {int(f['region']): f for f in data['faces']}
    adj = defaultdict(set)
    for pair in pairs:
        a, b = pair['regions']; adj[a].add(b); adj[b].add(a)
    seen = set(); components = []
    for seed in sorted(adj):
        if seed in seen: continue
        stack = [seed]; component = set()
        while stack:
            node = stack.pop()
            if node in component: continue
            component.add(node); stack.extend(adj[node] - component)
        seen |= component; components.append(component)
    regions = sorted(max(components, key=lambda c: (len(c), -min(c))))
    # Extend exactly one ring, accepting only ordinary reciprocal continuous floors.
    original_regions = regions.copy()
    expansion = []
    for a in original_regions:
        r = g['regions'][a]
        for edge, b in enumerate(r['neighbors']):
            if b is None or b in original_regions: continue
            other = g['regions'][b]; reason = None
            ids = [r['vertex_indices'][edge], r['vertex_indices'][(edge + 1) % 4]]
            matches = [j for j in range(4) if set(ids) == set([other['vertex_indices'][j], other['vertex_indices'][(j + 1) % 4]]) and other['neighbors'][j] == a]
            if b not in faces or other.get('record_role') != 'primary_region' or other.get('floor_subdivisions') or other['flags'] & 0x10: reason = 'special/subdivision'
            elif len(matches) != 1: reason = 'nonstandard connection'
            elif any(other['floor_corners'][other['vertex_indices'].index(v)] != r['floor_corners'][r['vertex_indices'].index(v)] for v in ids): reason = 'height discontinuity'
            if reason: expansion.append(dict(region=a, neighbor=b, status=reason)); continue
            fs = [[[v * 64 for v in p] for p in faces[x]['points']] for x in [a, b]]
            p, q = [fs[0][r['vertex_indices'].index(v)] for v in ids]
            mid = [(p[i] + q[i]) / 2 for i in range(3)]
            ends = []
            for face in fs:
                c = [sum(p[i] for p in face) / 4 for i in range(3)]
                distance = math.hypot(c[0] - mid[0], c[2] - mid[2])
                if distance < 16: break
                ends.append([mid[i] + (c[i] - mid[i]) * min(32, distance / 2) / distance for i in range(3)])
            if len(ends) != 2 or math.dist(p, q) < 32:
                expansion.append(dict(region=a, neighbor=b, status='insufficient experimental clearance')); continue
            rel = lambda p: [p[i] - mid[i] for i in range(3)]
            pairs.append(dict(regions=[a, b], faces=[[rel(p) for p in face] for face in fs], start=rel(ends[0]), end=rel(ends[1])))
            adj[a].add(b); adj[b].add(a)
            expansion.append(dict(region=a, neighbor=b, status='added continuous candidate'))
    regions = sorted(set(original_regions) | {b for a in original_regions for b in adj[a]})
    origin = [v * 64 for v in faces[regions[0]]['points'][0]]

    def local(p): return [p[i] * 64 - origin[i] for i in range(3)]

    def seam(a, b):
        pair = next(p for p in pairs if set(p['regions']) == {a, b})
        source = faces[pair['regions'][0]]['points'][0]
        offset = [source[i] * 64 - pair['faces'][0][0][i] - origin[i] for i in range(3)]
        ends = [[p[i] + offset[i] for i in range(3)] for p in [pair['start'], pair['end']]]
        return ends if pair['regions'][0] == a else ends[::-1]
    waypoints = []; visited = set()

    def tour(a):
        visited.add(a)
        for b in sorted(adj[a]):
            if b in visited: continue
            before, after = seam(a, b); waypoints.extend([before, after]); tour(b); waypoints.extend([after, before])
    tour(regions[0])
    assert visited == set(regions)
    exits = []; untested = []
    for a in regions:
        r = g['regions'][a]
        for edge, b in enumerate(r['neighbors']):
            if b is None: continue
            item = dict(region=a, neighbor=b, edge=edge, points=[local(faces[a]['points'][i]) for i in [edge, (edge + 1) % 4]])
            if b not in regions: exits.append(item)
            elif b not in adj[a]: untested.append(item)
    shell = [f for f in data['shell'] if int(f['region']) in regions]
    fixture = dict(regions=regions, kind='connected rock-floor area', faces=[[local(p) for p in faces[r]['points']] for r in regions], shell=[[local(p) for p in f['points']] for f in shell], start=waypoints[0], end=waypoints[-1], waypoints=waypoints[1:], exits=exits, untested_internal=untested)
    files['connected_walk.json'] = json.dumps([fixture], indent=2).encode()
    audit = dict(regions=regions, region_count=len(regions), selected_edges=sum(len(adj[r]) for r in regions) // 2, original_region_count=len(original_regions), expansion=expansion, shell_counts=dict(Counter(f['kind'] for f in shell)), external_openings=exits, untested_internal=untested, waypoint_count=len(waypoints) - 1, scope='Tested-seam component plus one continuous candidate ring; original geometry translated only. Shell includes provisional boundary and interior spans. External openings are uncapped.')
    files['connected_walk_audit.json'] = json.dumps(audit, indent=2).encode()


def full_walk(g, data, connected, expanded_pairs, files):
    """build_full_walk.py, unchanged."""
    faces = {int(f['region']): f for f in data['faces']}
    origin = [faces[connected['regions'][0]]['points'][0][i] * 64 - connected['faces'][0][0][i] for i in range(3)]

    def local(p): return [p[i] * 64 - origin[i] for i in range(3)]
    checkpoints = []
    for pair in expanded_pairs:
        source = faces[pair['regions'][0]]['points'][0]
        offset = [source[i] * 64 - pair['faces'][0][0][i] - origin[i] for i in range(3)]
        checkpoints.append(dict(regions=pair['regions'], start=[pair['start'][i] + offset[i] for i in range(3)], end=[pair['end'][i] + offset[i] for i in range(3)]))
    markers = []
    for r in g['regions']:
        if r['id'] not in faces or not r['flags'] & 0x10: continue
        for e, n in enumerate(r['neighbors']):
            if n is not None: markers.append(dict(region=r['id'], neighbor=n, points=[local(faces[r['id']]['points'][i]) for i in [e, (e + 1) % 4]]))
    fixture = dict(regions=list(faces), faces=[[local(p) for p in f['points']] for f in faces.values()], shell=[[local(p) for p in f['points']] for f in data['shell']], start=connected['start'], end=connected['end'], waypoints=connected['waypoints'], checkpoints=checkpoints, exits=markers, kind='full recovered cave', minimum_floor_y=min(local(p)[1] for f in faces.values() for p in f['points']))
    files['full_walk.json'] = json.dumps([fixture], separators=(',', ':')).encode()
    audit = dict(floors=len(faces), shell=dict(Counter(f['kind'] for f in data['shell'])), checkpoints=len(checkpoints), special_link_markers=len(markers), origin=origin, scope='All recovered floor and shell geometry loaded together. No native dynamic objects, hazards or verified wall/UV parity. Special links marked, not repaired.')
    files['full_walk_audit.json'] = json.dumps(audit, indent=2).encode()


def prepare(game, tmp, h):
    h.map_geometry.export_geometry(game, 'L1_DC', tmp / 'geometry')
    h.map_materials.export_materials(game, 'L1_DC', tmp / 'materials')
    g = json.loads((tmp / 'geometry/geometry.json').read_text())
    assert g['source']['sha256'] == ORIGINALS['DAT/L1_DC.MIX'], 'geometry source'
    blob = (tmp / 'materials/texture.bin').read_bytes(); assert digest(blob) == CAVE_BLOB_SHA, 'cave texture blob'
    _, _, presets = h.map_surfaces.source_tables(game, 'L1_DC')
    regions = []
    for r in g['regions']:
        sel = struct.unpack('<22H', bytes.fromhex(r['raw_hex']))[16] & 255
        if sel == 255 or sel >= len(presets): continue
        resource = presets[sel]['resource']
        assert (resource < 0) == (sel in UNRESOLVED_PRESETS), ('negative preset resource', sel)
        descriptor = None if resource < 0 else h.map_surfaces.resolve_resource(resource, blob)[0]
        regions.append(dict(region=r['id'], preset=sel, descriptor_index=descriptor))
    bits = {2.0: 0, 1.0: 1, 0.5: 2, 0.25: 3}
    setup = dict(results=[dict(preset=x['index'], initial_flags=0, angle_word=x['angle'], offset_x_fixed=x['offset_x'], offset_y_fixed=x['offset_y'],
                               object_bytes_30_31=list(x['offsets']), object_flags_3e=bits[x['scale']] << 14) for x in presets])
    table = h.rotation_table(game); assert digest(table) == ROTATION_TABLE_SHA, 'rotation table'
    report = json.loads((tmp / 'materials/materials.json').read_text()); exported = {m['index'] for m in report['materials']}
    captured = {}
    for d in sorted({r['descriptor_index'] for r in regions if r['descriptor_index'] is not None}):
        if d not in exported: continue
        im = h.Image.open(tmp / 'materials' / f'material_{d:04d}' / 'mip_0_palette.png').convert('RGB')
        # Historical capture order: raw column-major file order read as rows of the same size (= transpose of the export).
        captured[d] = h.Image.frombytes('RGB', im.size, im.transpose(h.Image.Transpose.TRANSPOSE).tobytes())
    files = {}
    import_floors(g, dict(regions=regions), setup, table, captured, h.interior_build, h.Image, files)
    data = json.loads(files['floors.json'])
    traversal(g, data, False, files); traversal(g, data, True, files)
    connected_walk(g, data, json.loads(files['traversal_expanded.json']), files)
    full_walk(g, data, json.loads(files['connected_walk.json'])[0], json.loads(files['traversal_expanded.json']), files)
    return files, data


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    if overlaps(a.output_root, a.game): p.error(f'--output-root overlaps input {a.game}')
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    try:
        from types import SimpleNamespace
        import map_geometry, map_materials, map_surfaces
        from interior_spans import build as interior_build
        from lol2_rotation_table import rotation_table
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    h = SimpleNamespace(map_geometry=map_geometry, map_materials=map_materials, map_surfaces=map_surfaces, interior_build=interior_build,
                        rotation_table=rotation_table, Image=Image)
    with tempfile.TemporaryDirectory(prefix='original-floors-') as tmp:
        try:
            files, data = prepare(a.game, Path(tmp), h)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, TypeError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    out = a.output_root / PACK; out.mkdir(parents=True)
    for name, blob in sorted(files.items()): (out / name).write_bytes(blob)
    print('PASS original_floors:', data['summary'], 'files', len(files))


if __name__ == '__main__':
    main()
