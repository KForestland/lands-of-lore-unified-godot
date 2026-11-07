#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_escape_wall pack (wall.json, stage_1..4.png, escape_regions.json)
from explicit original game files.

  python3 tools/prepare_museum_escape_wall_media.py --game GAME --output-root FRESH

Replaces the historical inputs of prepare_museum_escape_wall.py and export_museum_escape_regions.py (both unchanged)
with the originals and published readers:
- control 97 from its original 33-byte placement row (build_game_atlas.section 0x18/0x64), template 33 and its
  children from the original metadata template/child tables (export_museum_movables.py layout);
- resources 408..411 from a fresh lol2/map_materials.export_materials L3_DH texture.bin (the pinned museum texture),
  lol2_material_format.sections / rgb_palette; 0x8F column payloads with map_materials.decode_column_payload;
- region 716/717/718 event links from audit_game_transition_owners.collect_owners, their stream-0 groups from the
  original stream 0x3C/0x84 with audit_game_actor_scripts.groups, polygons from the original region/vertex tables.
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
check passes. No historical export, no RE checkout, no constructor replay, no executable, no capstone.
"""
import argparse, hashlib, io, json, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'}
ARCHIVE_SHA = ORIGINALS['DAT/L3_DH.MIX']
GEOMETRY_KEY, GEOMETRY_SHA = 3106551060, 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'
META_KEY, META_SHA = 3105896470, 'f701bfed7800cb3d74ae1770878312930399c36e12f4518a1efc1c125f512a31'
MUSEUM_TEXTURE_SHA = '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07'
CONTROL, TEMPLATE, HOURGLASS, REGIONS = 97, 33, 226, [716, 717, 718]
PACK = 'assets/lol2/generated/museum_escape_wall'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def build(archive, blob, h):
    entries = {e['key']: e for e in h.parse_mix(archive)}
    ge, me = entries[GEOMETRY_KEY], entries[META_KEY]
    g, meta = [archive[e['offset']:e['offset'] + e['size']] for e in (ge, me)]
    assert digest(g) == GEOMETRY_SHA, 'geometry entry'
    assert digest(meta) == META_SHA, 'metadata entry'
    u32 = h.u32

    def round_trip(record):
        raw = bytes.fromhex(record['raw_hex'])
        assert archive[record['source_offset']:record['source_offset'] + len(raw)] == raw, 'source round trip'

    # Control 97 (audit_museum_hourglass.py placement(16, 97, 33, 0x18): godot [x, z, -y]).
    co_, _, rows = h.section(g, 0x18, 0x64, 33)
    row = rows[CONTROL * 33:(CONTROL + 1) * 33]
    x, y, heading, z = struct.unpack_from('<hhHh', row)
    p = dict(kind=16, index=CONTROL, source_offset=ge['offset'] + co_ + CONTROL * 33, raw_hex=row.hex(),
             godot_position=[x, z, -y])
    assert row[32] == TEMPLATE and heading == 16384, 'control 97 template/heading'

    # Template 33 (export_museum_movables.py layout).
    to, nt = u32(meta, 12), u32(meta, 0x44)
    co = to + nt * 60 + 4
    assert sum(meta[to + i * 60 + 50] for i in range(nt)) == u32(meta, co - 4), 'unaccounted children'
    first = sum(meta[to + i * 60 + 50] for i in range(TEMPLATE))
    raw_t = meta[to + TEMPLATE * 60:to + (TEMPLATE + 1) * 60]
    children = []
    for j in range(first, first + raw_t[50]):
        c = meta[co + j * 60:co + (j + 1) * 60]
        children.append(dict(index=j, source_offset=me['offset'] + co + j * 60, raw_hex=c.hex(), type_byte=c[59],
                             bounds=list(struct.unpack_from('<4b2B', c, 52)),
                             surfaces=[dict(resource=struct.unpack_from('<h', c, f * 8)[0],
                                            raw_hex=c[f * 8:f * 8 + 8].hex()) for f in range(6)]))
    t = dict(index=TEMPLATE, source_offset=me['offset'] + to + TEMPLATE * 60, raw_hex=raw_t.hex(),
             dimensions=list(raw_t[47:50]), children=children)

    # prepare_museum_escape_wall.py, unchanged apart from the readers.
    for r in [p, t, *t['children']]: round_trip(r)
    assert p['kind'] == 16 and p['index'] == 97 and p['godot_position'] == [1429, 0, -492], 'control 97 position'
    assert t['dimensions'] == [46, 4, 90], 'template 33 dimensions'
    b = blob
    s = h.sections(b); po = struct.unpack_from('<I', b, 4)[0]; pal = h.rgb_palette(b[po:po + 768], 6)
    frames, images = [], {}
    for stage, k in enumerate(range(408, 412), 1):
        child = t['children'][stage - 1]; assert child['surfaces'][2]['resource'] == k, ('stage resource', k)
        assert int.from_bytes(bytes.fromhex(child['raw_hex'])[48:52], 'little') == 1 << stage, ('stage mask', k)
        v = struct.unpack_from('<6H11I', b, s[2] + k * 56); payload = b[s[3] + v[7]:][:v[12]]
        flags, w, hh, n = struct.unpack_from('<4H', payload)
        if k == 408:
            assert flags == 0x8b and n == w * hh == len(payload) - 8, 'resource 408'
            pixels = bytes(payload[8 + x * hh + y] for y in range(hh) for x in range(w))
        else:  # legacy decode_columns accepted 0x8f with a full-length column payload
            assert flags == 0x8f and n == len(payload) - 8, ('column payload', k)
            pixels, unproven = h.decode_column_payload(payload[8:], w, hh); assert unproven is False
        assert (w, hh) == (128, 128), ('extent', k)
        rgba = bytes(c for i in pixels for c in [*pal[i * 3:i * 3 + 3], 255 if i else 0])
        filename = f'stage_{stage}.png'; png = io.BytesIO()
        h.Image.frombytes('RGBA', (w, hh), rgba).save(png, format='PNG'); images[filename] = png.getvalue()
        frames.append(dict(stage=stage, resource=k, file=filename, source_sha256=digest(payload), bounds=child['bounds']))
    wall = dict(position=p['godot_position'], source_record=97, template=33, heading=16384, frames=frames,
                scope='Pinned placement/template/child state masks and resources408..411. Original column pixels, index0 alpha. Runtime plane, yaw, light shaft, reveal seconds, sword damage and collision opening are authored.')

    # export_museum_escape_regions.py, with the links of audit_museum_hourglass.py (stream-0 groups that address
    # hourglass kind3/226, joined to their region event owners) read from the original records.
    start, _, stream = h.section(g, 0x3C, 0x84, 1)
    groups = {}
    for offset, commands in h.groups(stream):
        groups[offset] = dict(offset=offset, commands=[dict(
            offset=o, source_offset=ge['offset'] + start + o, opcode=body[0], kind=body[1],
            target=struct.unpack_from('<H', body, 2)[0], raw_hex=body.hex()) for o, body in commands])
    owners, _ = h.collect_owners(g, ge['offset'], u32(g, 0x58))
    rows_out = []
    for group in groups.values():
        if not any(c['kind'] == 3 and c['target'] == HOURGLASS for c in group['commands']):
            continue
        for owner in owners:
            if owner['stream'] != 0 or owner['owner_kind'] != 'region' or owner['group'] != group['offset']:
                continue
            n = owner['owner']
            if n not in REGIONS:
                continue
            commands = group['commands']
            for c in commands: round_trip(c)
            assert any(c['raw_hex'] == '0e03e20004030000' for c in commands), ('disable command', n)
            assert any(c['raw_hex'] == '1003e2000500' for c in commands), ('state5 command', n)
            offset = u32(g, 12) + 44 * n; raw = g[offset:offset + 44]; r = struct.unpack('<22H', raw)
            points = [struct.unpack_from('<ii', g, u32(g, 4) + 8 * i) for i in r[6:10]]
            rows_out.append(dict(region=n, polygon=[[x / 65536, -y / 65536] for x, y in points], record_hex=raw.hex(),
                                 source_offset=ge['offset'] + offset, group=group))
    assert len(rows_out) == 3 and sorted(r['region'] for r in rows_out) == REGIONS, 'escape regions'
    regions = dict(archive_sha256=digest(archive), regions=rows_out,
                   scope='Source polygons and disable/state5 command bytes. Grounded human center height and wall-clearance guards are authored restoration choices.')
    return wall, images, regions


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
        from audit_game_transition_owners import collect_owners
        from lol2_material_format import sections, rgb_palette
        import map_materials
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    h = SimpleNamespace(parse_mix=parse_mix, section=section, u32=u32, groups=groups, collect_owners=collect_owners,
                        sections=sections, rgb_palette=rgb_palette, decode_column_payload=map_materials.decode_column_payload,
                        Image=Image)
    archive = (a.game / 'DAT/L3_DH.MIX').read_bytes()
    with tempfile.TemporaryDirectory(prefix='museum-escape-wall-') as tmp:
        tmp = Path(tmp)
        try:
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            blob = (tmp / 'materials/texture.bin').read_bytes(); assert digest(blob) == MUSEUM_TEXTURE_SHA, 'museum texture'
            wall, images, regions = build(archive, blob, h)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    out = a.output_root / PACK; out.mkdir(parents=True)
    for name, data in images.items(): (out / name).write_bytes(data)
    (out / 'wall.json').write_text(json.dumps(wall, indent=2) + '\n')
    (out / 'escape_regions.json').write_text(json.dumps(regions, indent=2) + '\n')
    print('PASS museum_escape_wall: control', CONTROL, 'template', TEMPLATE, 'stages', sorted(images),
          'regions', [r['region'] for r in regions['regions']])


if __name__ == '__main__':
    main()
