#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_gate pack (gate.json, gate.png) from explicit original game files.

  python3 tools/prepare_museum_gate_media.py --game GAME --output-root FRESH

Replaces the historical inputs of prepare_museum_gate.py (unchanged), the museum_panel_20260913 export of
verify_museum_panel.py, with the originals and published readers:
- movable placement 77 from its original 41-byte row (build_game_atlas.section 0x24/0x70): template 58, angular mode
  byte 34 = 6, encoded half-degrees byte 36. travel_angle_units = byte36 * 2 * 65536 // 360, the value
  verify_museum_panel.py asserts its constructor / angular-conversion / full-target replay produces;
- position from the placement, width/height from template 58 dimensions, resource 908 from its child surface;
- gate.png = resource 908 mip 0 from a fresh lol2/map_materials.export_materials L3_DH texture.bin (the pinned museum
  texture), lol2_material_format.sections / rgb_palette, map_materials.decode_column_payload, index 0 alpha.
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
check passes. No historical export, no RE checkout, no constructor replay, no executable, no capstone.
"""
import argparse, hashlib, io, json, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'}
GEOMETRY_KEY, GEOMETRY_SHA = 3106551060, 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'
META_KEY, META_SHA = 3105896470, 'f701bfed7800cb3d74ae1770878312930399c36e12f4518a1efc1c125f512a31'
MUSEUM_TEXTURE_SHA = '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07'
RECORD, TEMPLATE, RESOURCE = 77, 58, 908
PACK = 'assets/lol2/generated/museum_gate'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def build(archive, blob, h):
    entries = {e['key']: e for e in h.parse_mix(archive)}
    ge, me = entries[GEOMETRY_KEY], entries[META_KEY]
    geo, meta = [archive[e['offset']:e['offset'] + e['size']] for e in (ge, me)]
    assert digest(geo) == GEOMETRY_SHA, 'geometry entry'
    assert digest(meta) == META_SHA, 'metadata entry'
    u32 = h.u32

    _, _, rows = h.section(geo, 0x24, 0x70, 41)
    d = rows[RECORD * 41:(RECORD + 1) * 41]
    assert d[32] == TEMPLATE and d[34] == 6, 'panel fixture'  # verify_museum_panel.py check
    x, y, heading, height = struct.unpack_from('<hhHh', d)
    angle = (d[36] * 2 * 65536) // 360
    assert (x, y, heading, height, d[36], d[38]) == (-4060, 844, 0, 0, 54, 0), 'placement 77'

    to, nt = u32(meta, 12), u32(meta, 0x44)
    co = to + nt * 60 + 4
    t = meta[to + TEMPLATE * 60:to + (TEMPLATE + 1) * 60]
    width, _, tall = t[47:50]
    assert t[50] == 1, 'template 58 child count'
    first = sum(meta[to + i * 60 + 50] for i in range(TEMPLATE))
    child = meta[co + first * 60:co + (first + 1) * 60]
    surfaces = [struct.unpack_from('<h', child, f * 8)[0] for f in range(6)]
    assert child[59] == 0 and surfaces[2] == RESOURCE, 'template 58 child surface'
    assert list(struct.unpack_from('<4b2B', child, 52)) == [-width // 2, width // 2, -1, 0, 0, tall], 'child bounds'

    # verify_museum_panel.py resource 908 mip 0 (the image prepare_museum_gate.py copies).
    b = blob
    s = h.sections(b); po = u32(b, 4); pal = h.rgb_palette(b[po:po + 768], 6)
    v = struct.unpack_from('<6H11I', b, s[2] + RESOURCE * 56)
    payload = b[s[3] + v[7]:][:v[12]]
    flags, w, hh, n = struct.unpack_from('<4H', payload)
    assert flags in (0x8f, 0x808f) and n == len(payload) - 8, 'column payload'  # legacy decode_columns acceptance
    assert (w, hh) == (v[1], v[2]), 'mip dimensions'
    pixels, unproven = h.decode_column_payload(payload[8:], w, hh); assert unproven is False
    rgba = bytes(c for i in pixels for c in [*pal[i * 3:i * 3 + 3], 255 if i else 0])
    png = io.BytesIO(); h.Image.frombytes('RGBA', (w, hh), rgba).save(png, format='PNG')

    gate = dict(record=77, template=58, position=[x, height, -y], width=width, height=tall,
                travel_angle_units=angle,
                scope='Source placement/bounds/artwork and angular target. Diagnostic column decoder and index0 alpha; flat panel, left-edge vertical hinge, negative yaw away from approach and1.2second duration are modern reconstruction settings. AnimatableBody3D uses a2-unit-thick box; native collision/direction not reproduced.')
    assert (gate['position'], gate['width'], gate['height'], angle) == ([-4060, 0, -844], 54, 78, 19660), 'gate values'
    return gate, png.getvalue()


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
        from lol2_source_format import parse_mix
        from build_game_atlas import section, u32
        from lol2_material_format import sections, rgb_palette
        import map_materials
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    h = SimpleNamespace(parse_mix=parse_mix, section=section, u32=u32, sections=sections, rgb_palette=rgb_palette,
                        decode_column_payload=map_materials.decode_column_payload, Image=Image)
    archive = (a.game / 'DAT/L3_DH.MIX').read_bytes()
    with tempfile.TemporaryDirectory(prefix='museum-gate-') as tmp:
        tmp = Path(tmp)
        try:
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            blob = (tmp / 'materials/texture.bin').read_bytes(); assert digest(blob) == MUSEUM_TEXTURE_SHA, 'museum texture'
            gate, png = build(archive, blob, h)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    out = a.output_root / PACK; out.mkdir(parents=True)
    (out / 'gate.png').write_bytes(png)
    (out / 'gate.json').write_text(json.dumps(gate, indent=2) + '\n')
    print('PASS museum_gate: record', RECORD, 'template', TEMPLATE, 'resource', RESOURCE,
          'travel_angle_units', gate['travel_angle_units'])


if __name__ == '__main__':
    main()
