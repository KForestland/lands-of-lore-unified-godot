#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/hive_rune_entry pack (entry.json, mNNNN.png) and the legacy source record
docs/hive-rune-entry-source.json from explicit original game files.

  python3 tools/prepare_hive_rune_entry_media.py --game GAME --output-root FRESH

prepare_hive_rune_entry.py (unchanged) reads the historical hive_geometry_20260914/geometry.json (return region 679)
and the historical all_maps_20260922/L5_HC static_assemblies export (control 0 faces and materials). This tool keeps
its control/event/group/prop/return-pose logic unchanged and replaces those inputs:
- control 0's 32 faces from the original static placement row and template 64 child records, with the published
  export_map_movables face order and quad UVs (_box_faces, _QUAD_UV, _QUAD_UV_FACE3) and the published RE-free
  verify_chain_rotation model (prepare_jungle_followup_gate_media.model) on lol2_rotation_table: the exporter's type0
  face loop, including its mode-0 / state-face split and negative-resource indirection;
- materials from a fresh lol2/map_materials.export_materials(L5_HC) (texture.bin = the pinned Hive blob);
- return region 679 from a fresh lol2/map_geometry.export_geometry(L5_HC).
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
check passes. No historical export, RE checkout, constructor replay or capstone.
"""
import argparse, hashlib, json, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L5_HC.MIX': 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8',
             'LOLG.DAT': 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'}
GEOMETRY_KEY, META_KEY = 3776990464, 3776335874
HIVE_BLOB_SHA = 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
ROTATION_TABLE_SHA = 'd7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'
INITIAL_MODE = 0  # export_map_movables.py: constructor initial mode
PACK = 'assets/lol2/generated/hive_rune_entry'
DOCS = 'docs/hive-rune-entry-source.json'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def control_faces(row, meta, blob, available, h):
    """export_map_movables.py type0 face loop for one static_assembly placement (index 0)."""
    u32 = h.u32
    to, nt = u32(meta, 12), u32(meta, 0x44); co = to + nt * 60 + 4
    assert sum(meta[to + i * 60 + 50] for i in range(nt)) == u32(meta, co - 4), 'unaccounted children'
    x, y, heading, height = struct.unpack_from('<hhHh', row); template = row[32]
    first = sum(meta[to + i * 60 + 50] for i in range(template)); count = meta[to + template * 60 + 50]
    table = struct.unpack('<4096i', h.rotation_table_bytes)
    origin = (x << 16, y << 16); faces, state_faces, issues = [], [], []
    base = dict(placement='static_0', placement_kind='static_assembly', source_index=0, template=template)
    for j in range(first, first + count):
        c = meta[co + j * 60:co + (j + 1) * 60]
        mask, kind = u32(c, 48), c[59]; initially_active = (mask & (1 << INITIAL_MODE)) != 0
        if mask == 0: continue
        if kind != 0:
            if initially_active: issues.append(dict(child=j, child_type=kind))
            continue
        orders = h._box_faces(list(struct.unpack_from('<4b2B', c, 52)))
        target = faces if initially_active else state_faces
        for fi in range(6):
            rid = struct.unpack_from('<h', c, fi * 8)[0]
            if rid == 0: continue
            indirection = None
            if rid < 0: rid, indirection = h.resolve_resource(rid, blob)
            assert rid in available, ('material missing', rid)
            points = []
            for lx, lz, ly in orders[fi]:
                wx, wy = h.model((lx << 16, ly << 16), origin, heading, table)
                points.append([wx / 65536.0, lz + height, -(wy / 65536.0)])
            uv = h._QUAD_UV_FACE3 if fi == 3 else h._QUAD_UV
            face = dict(kind='movable', region=None, **base, child=j, face=fi, child_mask=mask, resource_id=rid,
                        points=points, uv=[list(v) for v in uv], material=rid)
            if indirection is not None: face['indirection'] = indirection
            if not initially_active: face['hidden'] = True; face['mask'] = mask
            target.append(face)
    assert not issues, ('unsupported children', issues)
    return faces, state_faces


def build(game, tmp, h):
    archive = (game / 'DAT/L5_HC.MIX').read_bytes()
    entries = {e['key']: e for e in h.parse_mix(archive)}
    entry, me = entries[GEOMETRY_KEY], entries[META_KEY]
    raw = archive[entry['offset']:][:entry['size']]; meta = archive[me['offset']:me['offset'] + me['size']]
    # prepare_hive_rune_entry.py, unchanged apart from its two historical inputs.
    _, _, controls = h.section(raw, 0x18, 0x64, 33); row = controls[:33]
    assert row.hex() == 'baf32e18d8621cf981145302260a7f0000000000010000000000000024001c0040', 'control 0'
    _, _, event_blob = h.section(raw, 0x40, 0x88, 1)
    listing = list(h.events(event_blob, struct.unpack_from('<H', row, 12)[0]))
    assert any(k == 4 and b.hex() == '0a047c14000000000000' for _, k, b, _ in listing), 'control 0 event'
    _, _, stream = h.section(raw, 0x44, 0x8c, 1); commands = [b for _, b in dict(h.groups(stream))[5244]]
    assert [b.hex() for b in commands] == ['c59082020a00', '090347001500', '0c1000000b00', '12010000d4f38c18000005000020000a0000'], 'group 5244'
    reposition = commands[-1]; x, y, z = struct.unpack_from('<hhh', reposition, 4); flags, bearing = struct.unpack_from('<HH', reposition, 10)
    assert flags == 5 and not flags & 0x100 and (x, y) == (-3116, 6284), 'reposition'
    h.map_geometry.export_geometry(game, 'L5_HC', tmp / 'geometry')
    terrain = json.loads((tmp / 'geometry/geometry.json').read_text())
    assert terrain['source']['sha256'] == digest(archive), 'geometry source'
    return_region = terrain['regions'][679]
    assert return_region['floor_corners'] == [-1659] * 4, 'return floor'
    polygon = [(terrain['vertices_fixed'][v][0] / 65536, -terrain['vertices_fixed'][v][1] / 65536) for v in return_region['vertex_indices']]
    cross = [(b[0] - a[0]) * (-y - a[1]) - (b[1] - a[1]) * (x - a[0]) for a, b in zip(polygon, polygon[1:] + polygon[:1])]
    assert all(c >= 0 for c in cross) or all(c <= 0 for c in cross), 'return point inside region 679'
    h.map_materials.export_materials(game, 'L5_HC', tmp / 'materials')
    blob = (tmp / 'materials/texture.bin').read_bytes(); assert digest(blob) == HIVE_BLOB_SHA, 'Hive texture blob'
    available = {m['index'] for m in json.loads((tmp / 'materials/materials.json').read_text())['materials']}
    visible, hidden = control_faces(row, meta, blob, available, h)
    faces = [f.copy() for f in visible + hidden]; assert len(faces) == 32, ('control 0 faces', len(faces))
    files = {}
    for face in faces:
        name = 'm%04d.png' % face['resource_id']
        files[PACK + '/' + name] = (tmp / 'materials' / ('material_%04d' % face['resource_id']) / 'mip_0_palette.png').read_bytes()
        face['material'] = name
    vertices = [p for f in faces for p in f['points']]
    bounds = [[min(p[i] for p in vertices), max(p[i] for p in vertices)] for i in range(3)]
    _, _, props = h.section(raw, 0x14, 0x60, 37); prop = props[327 * 37:328 * 37]
    prop_events = list(h.events(event_blob, struct.unpack_from('<H', prop, 12)[0])); assert not prop_events, 'prop 327 events'
    source = dict(archive_sha256=digest(archive), geometry_sha256=digest(raw), control=0, placement_hex=row.hex(), events=[dict(kind=k, raw=b.hex(), predicate=p) for _, k, b, p in listing], stream=1, group=5244, commands=[b.hex() for b in commands], room_index=11, room='RUNES', return_pose=dict(xz=[x, -y], preserve_height=True, bearing=bearing, flags=flags, support_region=679, support_floor=-1659), property21_target=dict(prop=327, placement_hex=prop.hex(), events=[]), bounds=bounds, faces=faces, limits='Source control assembly and complete command sequence. Live E uses the source mesh. Return support floor is source geometry; lifting an embedded Godot body to it is an explicit collision adapter, not an opcode18 height operand. Opcode197 marker enable, property21 dispatch and opcode18 return ordering must be retained. Inert prop327 has no source event list; full live command execution not claimed.')
    files[PACK + '/entry.json'] = (json.dumps(source, indent=2) + '\n').encode()
    report = {k: v for k, v in source.items() if k != 'faces'}; report['faces'] = len(faces)
    files[DOCS] = (json.dumps(report, indent=2) + '\n').encode()
    return files, source, len(hidden)


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
        import map_geometry, map_materials
        from map_surfaces import resolve_resource
        from build_game_atlas import parse_mix, section, u32
        from audit_game_transition_owners import events
        from audit_game_actor_scripts import groups
        from lol2_rotation_table import rotation_table
        from export_map_movables import _box_faces, _QUAD_UV, _QUAD_UV_FACE3
        from prepare_jungle_followup_gate_media import model
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    with tempfile.TemporaryDirectory(prefix='hive-rune-entry-') as tmp:
        try:
            table = rotation_table(a.game); assert digest(table) == ROTATION_TABLE_SHA, 'rotation table'
            h = SimpleNamespace(map_geometry=map_geometry, map_materials=map_materials, resolve_resource=resolve_resource, parse_mix=parse_mix,
                                section=section, u32=u32, events=events, groups=groups, rotation_table_bytes=table, _box_faces=_box_faces,
                                _QUAD_UV=_QUAD_UV, _QUAD_UV_FACE3=_QUAD_UV_FACE3, model=model)
            files, source, hidden = build(a.game, Path(tmp), h)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, TypeError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    for rel, data in sorted(files.items()):
        (a.output_root / rel).parent.mkdir(parents=True, exist_ok=True); (a.output_root / rel).write_bytes(data)
    print('PASS hive_rune_entry: control0', len(source['faces']), 'source faces (hidden', str(hidden) + '), event4 -> group5244 -> RUNES; return XZ',
          source['return_pose']['xz'], 'materials', sorted(n for n in files if n.endswith('.png')))


if __name__ == '__main__':
    main()
