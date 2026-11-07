#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_dragon_door pack (door.json, door.png) from explicit original game
files.

  python3 tools/prepare_museum_dragon_door_media.py --game GAME --output-root FRESH

Replaces the historical inputs of prepare_museum_dragon_door.py (unchanged) with the originals and published readers:
- movable placement 82 from the original 41-byte movable row (build_game_atlas.section 0x24/0x70). fixed_xyz is
  [x, y, height] << 16, the value export_museum_movables.py asserts its constructor replay produces;
- template 30 and its child 66 from the original metadata template/child tables (export_museum_movables.py layout);
- the open group 12536 from the original stream 0x44/0x8C with audit_game_actor_scripts.groups;
- the trigger record from the original geometry;
- resource 434 artwork from a fresh lol2/map_materials.export_materials L3_DH texture.bin (the pinned museum texture),
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
PLACEMENT, TEMPLATE, RESOURCE, OPEN_GROUP = 82, 30, 434, 12536
PACK = 'assets/lol2/generated/museum_dragon_door'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def build(archive, blob, parse_mix, section, u32, groups, sections, rgb_palette, Image):
    entries = {e['key']: e for e in parse_mix(archive)}
    ge, me = entries[GEOMETRY_KEY], entries[META_KEY]
    geo, meta = [archive[e['offset']:e['offset'] + e['size']] for e in (ge, me)]
    assert digest(geo) == GEOMETRY_SHA, 'geometry entry'
    assert digest(meta) == META_SHA, 'metadata entry'

    # export_museum_movables.py template/child records, unchanged layout.
    to, nt = u32(meta, 12), u32(meta, 0x44)
    co = to + nt * 60 + 4
    nchildren = u32(meta, co - 4)
    first = sum(meta[to + i * 60 + 50] for i in range(TEMPLATE))
    t = meta[to + TEMPLATE * 60:to + (TEMPLATE + 1) * 60]
    assert sum(meta[to + i * 60 + 50] for i in range(nt)) == nchildren, 'unaccounted children'
    parts = []
    for j in range(first, first + t[50]):
        c = meta[co + j * 60:co + (j + 1) * 60]
        parts.append(dict(index=j, source_offset=me['offset'] + co + j * 60,
                          raw_hex=c.hex(), type_byte=c[59],
                          bounds=list(struct.unpack_from('<4b2B', c, 52)),
                          surfaces=[dict(resource=struct.unpack_from('<h', c, f * 8)[0],
                                         raw_hex=c[f * 8:f * 8 + 8].hex()) for f in range(6)]))
    template = dict(index=TEMPLATE, source_offset=me['offset'] + to + TEMPLATE * 60,
                    raw_hex=t.hex(), dimensions=list(t[47:50]), children=parts)

    po, _, rows = section(geo, 0x24, 0x70, 41)
    d = rows[PLACEMENT * 41:(PLACEMENT + 1) * 41]
    x, y, heading, height = struct.unpack_from('<hhHh', d)
    assert d[32] == TEMPLATE, 'placement template'
    placement = dict(index=PLACEMENT, template=d[32], native_xyz=[x, y, height],
                     heading=heading, fixed_xyz=[x << 16, y << 16, height << 16], raw_hex=d.hex(),
                     source_offset=ge['offset'] + po + PLACEMENT * 41,
                     motion_bytes_unassigned=list(d[33:]), has_children=bool(parts))
    for r in [placement, template, *template['children']]:  # prepare_museum_dragon_door.py source check
        raw = bytes.fromhex(r['raw_hex']); assert archive[r['source_offset']:r['source_offset'] + len(raw)] == raw
    assert template['children'][0]['surfaces'][2]['resource'] == RESOURCE, 'door surface'

    trigger = geo[u32(geo, 0x40) + 6226:][:14]
    assert trigger.hex() == '0a04f83000000000000004131300', 'trigger'

    start, _, stream = section(geo, 0x44, 0x8C, 1)
    commands = dict(groups(stream))[OPEN_GROUP]
    group = dict(offset=OPEN_GROUP, commands=[dict(
        offset=offset, source_offset=ge['offset'] + start + offset, opcode=body[0], kind=body[1],
        target=struct.unpack_from('<H', body, 2)[0], raw_hex=body.hex()) for offset, body in commands])
    assert [c['raw_hex'] for c in group['commands']] == ['012052006400', '102052000200'], 'open group'
    for c in group['commands']:
        raw = bytes.fromhex(c['raw_hex']); assert archive[c['source_offset']:c['source_offset'] + len(raw)] == raw

    # prepare_museum_dragon_door.py artwork, unchanged.
    b = blob
    s = sections(b); v = struct.unpack_from('<6H11I', b, s[2] + RESOURCE * 56); payload = b[s[3] + v[7]:][:v[12]]
    f, w, h, n = struct.unpack_from('<4H', payload); assert f == 0xa9 and n == w * h == len(payload) - 8, 'resource 434'
    idx = bytes(payload[8 + x * h + y] for y in range(h) for x in range(w)); po = struct.unpack_from('<I', b, 4)[0]
    pal = rgb_palette(b[po:po + 768], 6)
    png = io.BytesIO()
    Image.frombytes('RGB', (w, h), bytes(c for i in idx for c in pal[i * 3:i * 3 + 3])).save(png, format='PNG')
    door = dict(placement=placement, template=template, trigger_hex=trigger.hex(), open_group=group,
                payload_sha256=digest(payload),
                scope='Source object82/template30/resource434 and open command. Authored E interaction and vertical80-unit/1sec travel; native motion and predicate acceptance unverified.')
    return door, png.getvalue()


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
        from audit_game_actor_scripts import groups
        from lol2_material_format import sections, rgb_palette
        import map_materials
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    archive = (a.game / 'DAT/L3_DH.MIX').read_bytes()
    with tempfile.TemporaryDirectory(prefix='museum-dragon-door-') as tmp:
        tmp = Path(tmp)
        try:
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            blob = (tmp / 'materials/texture.bin').read_bytes(); assert digest(blob) == MUSEUM_TEXTURE_SHA, 'museum texture'
            door, png = build(archive, blob, parse_mix, section, u32, groups, sections, rgb_palette, Image)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    out = a.output_root / PACK; out.mkdir(parents=True)
    (out / 'door.png').write_bytes(png)
    (out / 'door.json').write_text(json.dumps(door, indent=2) + '\n')
    print('PASS museum_dragon_door: placement', PLACEMENT, 'template', TEMPLATE, 'child',
          door['template']['children'][0]['index'], 'resource', RESOURCE, 'open group', OPEN_GROUP)


if __name__ == '__main__':
    main()
