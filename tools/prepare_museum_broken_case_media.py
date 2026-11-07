#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_broken_case pack (case.json, material_262/263/264/265/266/269.png)
from explicit original game files.

  python3 tools/prepare_museum_broken_case_media.py --game GAME --output-root FRESH

Replaces the historical inputs of prepare_museum_broken_case.py (unchanged) with the originals and published readers:
- control 181 placement from its original 33-byte static placement row (build_game_atlas.section 0x18/0x64);
- template 9 (Case) and its children 26..36 from the original metadata child table;
- the 46 type0 faces built from the child bounds and surface slots with the face vertex order and quad UVs of the
  published export_map_movables.py (copied; that module needs capstone and the RE root at import). Heading 0, so the
  native model() rotation is the identity;
- materials from a fresh lol2/map_materials.export_materials L3_DH (mip_0_palette.png).
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
check passes. No historical export, no RE checkout, no constructor replay, no executable, no capstone.
"""
import argparse, hashlib, json, shutil, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'}
GEOMETRY_KEY, GEOMETRY_SHA = 3106551060, 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'
META_KEY, META_SHA = 3105896470, 'f701bfed7800cb3d74ae1770878312930399c36e12f4518a1efc1c125f512a31'
PLACEMENT_HEX = 'd503f80900000f0082049d01ae157f000000000001000000000000001400000009'
CONTROL, TEMPLATE = 181, 9
CASE_CHILDREN = list(range(26, 35))
SWORD_CHILD, EMPTY_CHILD = 35, 36
FACE_COUNT = 46
# Godot layer 20. Player capsules use mask 1, so only ray queries with the default mask see it.
VISIBILITY_LAYER = 1 << 19
PACK = 'assets/lol2/generated/museum_broken_case'
# export_map_movables.py _FACE_VERTEX_ORDER / _QUAD_UV / _QUAD_UV_FACE3, unchanged. Order (x, z, y); z is height.
_FACE_VERTEX_ORDER = [
    lambda b: [(b[0], b[5], b[3]), (b[0], b[5], b[2]), (b[1], b[5], b[2]), (b[1], b[5], b[3])],
    lambda b: [(b[0], b[4], b[2]), (b[0], b[4], b[3]), (b[1], b[4], b[3]), (b[1], b[4], b[2])],
    lambda b: [(b[0], b[5], b[2]), (b[1], b[5], b[2]), (b[1], b[4], b[2]), (b[0], b[4], b[2])],
    lambda b: [(b[1], b[5], b[3]), (b[0], b[5], b[3]), (b[0], b[4], b[3]), (b[1], b[4], b[3])],
    lambda b: [(b[1], b[5], b[2]), (b[1], b[5], b[3]), (b[1], b[4], b[3]), (b[1], b[4], b[2])],
    lambda b: [(b[0], b[5], b[3]), (b[0], b[5], b[2]), (b[0], b[4], b[2]), (b[0], b[4], b[3])],
]
_QUAD_UV = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
_QUAD_UV_FACE3 = [(1.0, 0.0), (0.0, 0.0), (0.0, 1.0), (1.0, 1.0)]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def face_box(faces):  # prepare_museum_broken_case.py, unchanged
    xs = [p[0] for f in faces for p in f['points']]
    hs = [p[1] for f in faces for p in f['points']]
    zs = [p[2] for f in faces for p in f['points']]
    return [min(xs), max(xs), min(hs), max(hs), min(zs), max(zs)]


def child_faces(raw, x, y, heading, base):
    """export_map_movables.py type0 face loop for one mode-0 child, heading 0 (identity rotation)."""
    assert heading == 0, 'only heading 0 is the identity'
    bounds = list(struct.unpack_from('<4b2B', raw, 52))
    faces = []
    for fi, order in enumerate(_FACE_VERTEX_ORDER):
        rid = struct.unpack_from('<h', raw, fi * 8)[0]
        if rid == 0:
            continue
        assert rid > 0, 'negative surface indirection not expected for the Case'
        points = [[((x << 16) + (lx << 16)) / 65536.0, lz + base, -(((y << 16) + (ly << 16)) / 65536.0)]
                  for lx, lz, ly in order(bounds)]
        faces.append(dict(face=fi, resource_id=rid, points=points,
                          uv=[list(v) for v in (_QUAD_UV_FACE3 if fi == 3 else _QUAD_UV)]))
    return faces


def build(archive, parse_mix, section, u32):
    """prepare_museum_broken_case.py main(), with the historical export replaced by the original records."""
    entries = {e['key']: archive[e['offset']:e['offset'] + e['size']] for e in parse_mix(archive)}
    geometry, meta = entries[GEOMETRY_KEY], entries[META_KEY]
    assert digest(geometry) == GEOMETRY_SHA, 'geometry entry'
    assert digest(meta) == META_SHA, 'metadata entry'
    template_at, template_count = u32(meta, 12), u32(meta, 0x44)
    template = meta[template_at + 9 * 60:template_at + 10 * 60]
    assert b'Case' in template and template[50] == 11, 'template 9'
    width, depth, height = template[0x2F], template[0x30], template[0x31]
    assert (width, depth, height) == (22, 22, 70), 'contact bytes'
    child_at = template_at + template_count * 60 + 4
    first = sum(meta[template_at + index * 60 + 50] for index in range(9))
    assert first == 26, 'first child'
    raw_children = {first + i: meta[child_at + (first + i) * 60:child_at + (first + i + 1) * 60]
                    for i in range(11)}

    _, _, table = section(geometry, 0x18, 0x64, 33)
    row = table[CONTROL * 33:(CONTROL + 1) * 33]
    assert row.hex() == PLACEMENT_HEX and row[32] == TEMPLATE, 'control 181 placement'
    x, y, heading, base = struct.unpack_from('<hhHh', row)
    assert (x, y, heading, base) == (981, 2552, 0, 15), 'control 181 position'

    # The exporter's per-child classification for this placement: nine mode-0 type0 children draw, child 35 is the
    # type1 mode-0 sword (not a type0 face box), child 36 misses mode 0 (mask 2) and has no surfaces.
    faces = []
    for index, raw in raw_children.items():
        mask, kind = u32(raw, 48), raw[59]
        if index in CASE_CHILDREN:
            assert kind == 0 and mask == 0xFFFFFFFF, ('case child', index)
            faces += [dict(child=index, **f) for f in child_faces(raw, x, y, heading, base)]
        else:
            assert (index, kind, mask) in ((SWORD_CHILD, 1, 1), (EMPTY_CHILD, 0, 2)), ('excluded child', index)
    assert len(faces) == FACE_COUNT, 'face count'

    children = []
    for index in CASE_CHILDREN:
        raw = raw_children[index]
        assert raw[59] == 0 and u32(raw, 48) == 0xFFFFFFFF
        bounds = list(struct.unpack_from('<4b2B', raw, 52))
        own = [f for f in faces if f['child'] == index]
        expected = [x + bounds[0], x + bounds[1], base + bounds[4], base + bounds[5],
                    -(y + bounds[3]), -(y + bounds[2])]
        assert face_box(own) == expected, (index, face_box(own), expected)
        resources = [struct.unpack_from('<h', raw, slot * 8)[0] for slot in range(6)]
        assert sorted(f['face'] for f in own) == [s for s, r in enumerate(resources) if r > 0]
        children.append(dict(child=index, bounds=bounds, surface_resources=resources,
                             faces=len(own), child_hex=raw.hex()))

    sword, empty = raw_children[SWORD_CHILD], raw_children[EMPTY_CHILD]
    assert sword[59] == 1 and u32(sword, 48) == 1
    assert empty[59] == 0 and u32(empty, 48) == 2 and not any(
        struct.unpack_from('<h', empty, slot * 8)[0] for slot in range(6))
    local = [struct.unpack_from('<i', sword, off)[0] for off in (4, 8, 12)]
    assert local == [0, 38 << 16, 0]
    sword_bounds = list(struct.unpack_from('<4b2B', sword, 52))
    assert sword_bounds == [-8, 8, -8, 8, 38, 63]

    staged = [dict(child=f['child'], face=f['face'], resource=f['resource_id'],
                   material=str(f['resource_id']), points=f['points'], uv=f['uv']) for f in faces]
    envelope = face_box(faces)
    contact = dict(
        width=width, depth=depth, height=height, template_bytes_hex=template[0x2F:0x32].hex(),
        center=[x, base + height / 2, -y], size=[width, height, depth],
        min=[x - width / 2, base, -(y + depth / 2)], max=[x + width / 2, base + height, -(y - depth / 2)],
        collision_layer=1, collision_mask=0,
        note='0x5BE5D: +/-template[0x2F]/2, +/-template[0x30]/2 around the object after 0x111CAC '
             'rotates the tested point by heading word +0x1E (0 here). 0x5CF44 returns template[0x31]. '
             'Matches the face envelope exactly.')
    assert [contact['min'][0], contact['max'][0], contact['min'][1], contact['max'][1],
            contact['min'][2], contact['max'][2]] == envelope, 'contact envelope'
    native_sword = [x + local[0] / 65536, base + local[1] / 65536, -(y + local[2] / 65536)]
    resources = sorted({f['resource_id'] for f in faces})
    catalog = dict(
        id='museum:control181:case', control=181, template=9, template_name='Case',
        native_position=[x, y], height=base, heading=heading, placement_hex=PLACEMENT_HEX,
        children=children, excluded_children=[
            dict(child=SWORD_CHILD, reason='type1 mode-0 sword; scripts/lol2/museum_broken_thohan.gd'),
            dict(child=EMPTY_CHILD, reason='mode 1 (mask 2), all six surface ids 0')],
        faces=staged, materials={str(r): f'material_{r}.png' for r in resources},
        face_envelope=envelope, contact=contact,
        visibility=dict(collision_layer=VISIBILITY_LAYER, collision_mask=0,
                        note='Rendered faces as a ray-only occluder (modern adapter). Stone blocks the ray, '
                             'the open sides between posts do not. No source glass surface exists.'),
        sword_anchor=dict(
            export_position=[x, base, -(y + local[1] / 65536)], native_order_position=native_sword,
            child_local_fixed=local, child_bounds=sword_bounds,
            note='0x5B4E4 passes [child+4, child+0xC, child+8]. 0xF1A94 reads block+8 as height '
                 '(0xF1D55, same slot as object z at +8). child+8=38 is height, not Y.'),
        render=dict(shading='unshaded', cull='disabled', filter='nearest',
                    note='museum_review.gd convention for source faces'))
    return catalog, resources


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
        from lol2_source_format import parse_mix
        from build_game_atlas import section, u32
        import map_materials
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    archive = (a.game / 'DAT/L3_DH.MIX').read_bytes()
    with tempfile.TemporaryDirectory(prefix='museum-broken-case-') as tmp:
        tmp = Path(tmp)
        try:
            catalog, resources = build(archive, parse_mix, section, u32)
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            sources = {r: tmp / 'materials' / f'material_{r:04d}' / 'mip_0_palette.png' for r in resources}
            for r, source in sources.items(): assert source.is_file(), f'material {r} not exported'
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
        out = a.output_root / PACK; out.mkdir(parents=True)
        for r, source in sources.items(): shutil.copyfile(source, out / f'material_{r}.png')
        (out / 'case.json').write_text(json.dumps(catalog, indent=2) + '\n')
    print('PASS museum_broken_case: control181 faces', len(catalog['faces']), 'children',
          CASE_CHILDREN[0], '-', CASE_CHILDREN[-1], 'materials', resources, 'contact', catalog['contact']['size'])


if __name__ == '__main__':
    main()
