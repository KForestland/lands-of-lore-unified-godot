#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_gallery pack (gallery.json, painting.png) from explicit original
game files.

  python3 tools/prepare_museum_gallery_media.py --game GAME --output-root FRESH

Replaces the historical inputs of prepare_museum_gallery.py (unchanged) with the originals and published readers:
- movable placements 54 (painting), 53 (lever) and 51 (grate) from their original 41-byte rows
  (build_game_atlas.section 0x24/0x70). fixed_xyz is [x, y, height] << 16, the value export_museum_movables.py
  asserts its constructor replay produces;
- templates 28/41/71 and their children from the original metadata template/child tables (export_museum_movables.py
  layout);
- lever groups 12116/12140 from the original stream 0x44/0x8C with audit_game_actor_scripts.groups, and the lever
  trigger records from the original geometry;
- painting resource 421 from a fresh lol2/map_materials.export_materials L3_DH texture.bin (the pinned museum texture),
  lol2_material_format.sections / rgb_palette.
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
check passes. No historical export, no RE checkout, no constructor replay, no executable, no capstone.
"""
import argparse, hashlib, io, json, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'}
GEOMETRY_KEY, GEOMETRY_SHA = 3106551060, 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'
META_KEY, META_SHA = 3105896470, 'f701bfed7800cb3d74ae1770878312930399c36e12f4518a1efc1c125f512a31'
MUSEUM_TEXTURE_SHA = '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07'
PLACEMENTS, TEMPLATES, GROUPS, RESOURCE = [54, 53, 51], [28, 41, 71], [12116, 12140], 421
PACK = 'assets/lol2/generated/museum_gallery'


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

    # export_museum_movables.py template/child and placement records, unchanged layout.
    to, nt = u32(meta, 12), u32(meta, 0x44)
    co = to + nt * 60 + 4
    assert sum(meta[to + i * 60 + 50] for i in range(nt)) == u32(meta, co - 4), 'unaccounted children'

    def template(index):
        first = sum(meta[to + i * 60 + 50] for i in range(index))
        t = meta[to + index * 60:to + (index + 1) * 60]
        parts = []
        for j in range(first, first + t[50]):
            c = meta[co + j * 60:co + (j + 1) * 60]
            parts.append(dict(index=j, source_offset=me['offset'] + co + j * 60,
                              raw_hex=c.hex(), type_byte=c[59],
                              bounds=list(struct.unpack_from('<4b2B', c, 52)),
                              surfaces=[dict(resource=struct.unpack_from('<h', c, f * 8)[0],
                                             raw_hex=c[f * 8:f * 8 + 8].hex()) for f in range(6)]))
        return dict(index=index, source_offset=me['offset'] + to + index * 60,
                    raw_hex=t.hex(), dimensions=list(t[47:50]), children=parts)

    po, _, rows = h.section(geo, 0x24, 0x70, 41)

    def placement(i):
        d = rows[i * 41:(i + 1) * 41]
        x, y, heading, height = struct.unpack_from('<hhHh', d)
        assert d[32] < nt, 'unknown template'
        has_children = meta[to + d[32] * 60 + 50] > 0
        return dict(index=i, template=d[32], native_xyz=[x, y, height],
                    heading=heading, fixed_xyz=[x << 16, y << 16, height << 16], raw_hex=d.hex(),
                    source_offset=ge['offset'] + po + i * 41,
                    motion_bytes_unassigned=list(d[33:]), has_children=has_children)

    records = [placement(i) for i in PLACEMENTS]
    templates = [template(i) for i in TEMPLATES]
    assert [r['template'] for r in records] == TEMPLATES, 'placement templates'

    # prepare_museum_gallery.py, unchanged apart from the readers.
    def round_trip(r):
        raw = bytes.fromhex(r['raw_hex']); assert archive[r['source_offset']:r['source_offset'] + len(raw)] == raw, 'source round trip'
    for r in records + templates + [c for t in templates for c in t['children']]: round_trip(r)
    assert templates[0]['children'][0]['surfaces'][2]['resource'] == RESOURCE, 'painting surface'
    start, _, stream = h.section(geo, 0x44, 0x8C, 1)
    parsed = dict(h.groups(stream))
    groups = [dict(offset=g, commands=[dict(
        offset=o, source_offset=ge['offset'] + start + o, opcode=body[0], kind=body[1],
        target=struct.unpack_from('<H', body, 2)[0], raw_hex=body.hex()) for o, body in parsed[g]]) for g in GROUPS]
    assert [[c['raw_hex'] for c in g['commands']] for g in groups] == [['012035006400', '012033006400', '102035000100'], ['012035000000', '012033000000', '102035000000']], 'lever groups'
    for g in groups:
        for c in g['commands']: round_trip(c)
    trigger_offset = int.from_bytes(bytes.fromhex(records[1]['raw_hex'])[12:14], 'little')
    assert trigger_offset == 6026, 'lever trigger offset'
    trigger_bytes = geo[u32(geo, 0x40) + trigger_offset:][:28]
    assert trigger_bytes.hex() == '0a04542f00000000000004130e000a046c2f00000000000004130f00', 'lever trigger'
    b = blob
    s = h.sections(b); v = struct.unpack_from('<6H11I', b, s[2] + RESOURCE * 56); payload = b[s[3] + v[7]:][:v[12]]
    f, w, hh, n = struct.unpack_from('<4H', payload); assert f == 0x80a9 and n == w * hh == len(payload) - 8, 'resource 421'
    idx = bytes(payload[8 + x * hh + y] for y in range(hh) for x in range(w)); po = struct.unpack_from('<I', b, 4)[0]
    pal = h.rgb_palette(b[po:po + 768], 6)
    png = io.BytesIO()
    h.Image.frombytes('RGB', (w, hh), bytes(c for i in idx for c in pal[i * 3:i * 3 + 3])).save(png, format='PNG')
    gallery = dict(placements=records, templates=templates, lever_groups=groups, lever_trigger_hex=trigger_bytes.hex(),
                   painting_payload_sha256=digest(payload),
                   scope='Pinned placements/templates/lever command targets and original painting pixels. Authored E binding, painting slide, lever motion and grate rise; native interaction acceptance and travel not replayed.')
    return gallery, png.getvalue()


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
        from audit_game_actor_scripts import groups
        from lol2_material_format import sections, rgb_palette
        import map_materials
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    h = SimpleNamespace(parse_mix=parse_mix, section=section, u32=u32, groups=groups, sections=sections,
                        rgb_palette=rgb_palette, Image=Image)
    archive = (a.game / 'DAT/L3_DH.MIX').read_bytes()
    with tempfile.TemporaryDirectory(prefix='museum-gallery-') as tmp:
        tmp = Path(tmp)
        try:
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            blob = (tmp / 'materials/texture.bin').read_bytes(); assert digest(blob) == MUSEUM_TEXTURE_SHA, 'museum texture'
            gallery, png = build(archive, blob, h)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    out = a.output_root / PACK; out.mkdir(parents=True)
    (out / 'painting.png').write_bytes(png)
    (out / 'gallery.json').write_text(json.dumps(gallery, indent=2) + '\n')
    print('PASS museum_gallery: placements', PLACEMENTS, 'templates', TEMPLATES, 'groups', GROUPS, 'resource', RESOURCE)


if __name__ == '__main__':
    main()
