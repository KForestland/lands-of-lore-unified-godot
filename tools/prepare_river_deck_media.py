#!/usr/bin/env python3
"""Stage the complete assets/lol2/river_deck pack (deck.json, indices_86.png, chains.json, chain_27_0.png,
chain_28_0..25.png, chain_27.png, chain_28.png, regions.json) from explicit original game files.

  python3 tools/prepare_river_deck_media.py --game GAME --output-root FRESH

Replaces the RE-checkout inputs of catalogue_river_deck.py, export_river_chains.py and export_river_regions.py (all
unchanged) with the original L1_DC archive and published readers; their logic is otherwise unchanged:
- geometry entry 0xB1202500 parsed with the pinned header checks of the RE decode (vertices, 44-byte region records),
  lol2_source_format.parse_mix / build_game_atlas.u32;
- the cave texture blob from lol2/map_materials.export_materials(L1_DC) (texture.bin = the pinned cave cache blob
  102410e0...), lol2_material_format.sections / material_record / column_major_to_rows / png_rgb and
  lol2_creature_sprite_format.decode_rows (source-identical to the RE readers);
- the prop top height through lol2/map_props.region_height (the published port of selected_height's region branch).
chain_27.png and chain_28.png are the earlier frame-0 preview names; they are written as the same frame-0 bytes.
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
check passes. No historical export, RE checkout, constructor replay, executable or capstone.
"""
import argparse, hashlib, io, json, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L1_DC.MIX': '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'}
GEO_KEY, ASSEMBLY_KEY = 0xB1202500, 2971019266
CAVE_BLOB_SHA = '102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'  # lol2_extract_cave_materials.HASH
PACK = 'assets/lol2/river_deck'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def decode(mix, h):
    """lol2_extract_draracle_geometry.decode with its pinned checks: (entries, entry, raw, verts, records, regions)."""
    assert sha(mix) == ORIGINALS['DAT/L1_DC.MIX'], 'L1_DC.MIX'
    entries = h.parse_mix(mix); e = next(e for e in entries if e['key'] == GEO_KEY); raw = mix[e['offset']:e['offset'] + e['size']]
    assert h.u32(raw, 0) == 18, 'format marker'
    nv, nr, vo, ro = h.u32(raw, 0x50), h.u32(raw, 0x58), h.u32(raw, 4), h.u32(raw, 12)
    assert (nv, nr, vo, ro) == (2695, 1954, 5300, 54509), 'pinned geometry header'
    verts = list(struct.iter_unpack('<ii', raw[vo:vo + nv * 8]))
    records = [struct.unpack_from('<22H', raw, ro + i * 44) for i in range(nr)]
    for r in records:
        assert not any(x >= nv for x in r[6:10]), 'vertex reference'
        assert not any(x != 65535 and x >= nr for x in r[2:6]), 'region reference'
    regions = [dict(id=i, raw_hex=raw[ro + i * 44:ro + (i + 1) * 44].hex(), vertex_indices=list(r[6:10])) for i, r in enumerate(records)]
    return entries, e, raw, verts, records, regions


def png_l(w, h, pixels, Image):
    stream = io.BytesIO(); Image.frombytes('L', (w, h), pixels).save(stream, format='PNG'); return stream.getvalue()


def catalogue(mix, blob, h):
    """catalogue_river_deck.py main() with --game-root, unchanged apart from readers."""
    u32 = h.u32
    _, _, geometry, *_ = decode(mix, h)
    e = next(e for e in h.parse_mix(mix) if e['key'] == ASSEMBLY_KEY)
    assembly = mix[e['offset']:e['offset'] + e['size']]
    templates = u32(assembly, 12); count = u32(assembly, 0x44); children = templates + count * 60 + 4
    records = []
    for index in range(56, 62):
        offset = u32(geometry, 0x24) + index * 41
        record = geometry[offset:offset + 41]
        x, y, heading, z = struct.unpack_from('<hhHh', record)
        template = record[32]
        assert template == 49 and heading == 0, ('deck record', index)
        assert assembly[templates + template * 60 + 50] == 1, 'template 49 child count'
        child_offset = children + sum(assembly[templates + i * 60 + 50] for i in range(template)) * 60
        child = assembly[child_offset:child_offset + 60]
        bounds = list(struct.unpack_from('6b', child, 52)); assert bounds == [-35, 34, -75, 74, 0, 5], 'deck bounds'
        surfaces = [struct.unpack_from('<h', child, i * 8)[0] for i in range(6)]; assert surfaces == [86] * 6, 'deck surfaces'
        records.append(dict(index=index, native_xyz=[x, y, z], heading=heading, template=template, bounds_xyz=bounds, surface_ids=surfaces,
                            geometry_offset=offset, child_offset=child_offset, record_hex=record.hex(), child_hex=child.hex()))
    report = dict(geometry_sha256=sha(geometry), assembly_sha256=sha(assembly), records=records,
                  scope='Source placements and template bounds. Initial motion state, surface86 image binding and original bridge-collapse behavior not established.')
    material = h.material_record(blob, 86, allow_partial_mips=True)
    mip = material['mips'][0]; w, hh = mip['width'], mip['height']
    pixels = blob[mip['data_start']:mip['data_start'] + w * hh]; assert len(pixels) == w * hh, 'material 86 extent'
    rows = h.column_major_to_rows(pixels, w, hh)
    png = h.png_rgb(w, hh, bytes(c for value in rows for c in (value, value, value)))
    report['material'] = dict(descriptor=86, cache_sha256=CAVE_BLOB_SHA, width=w, height=hh, source_offset=mip['data_start'], pixels_sha256=sha(pixels),
                              png_sha256=sha(png), binding='Positive surface ID86 + source frame byte0 = descriptor86; shared type0 material rule.')
    return {'deck.json': (json.dumps(report, indent=2) + '\n').encode(), 'indices_86.png': png}


def chains(mix, blob, h):
    """export_river_chains.py, unchanged apart from readers and in-memory PNGs."""
    u32 = h.u32
    _, _, geo, *_ = decode(mix, h); e = next(e for e in h.parse_mix(mix) if e['key'] == ASSEMBLY_KEY); raw = mix[e['offset']:e['offset'] + e['size']]
    o, n = u32(raw, 8), u32(raw, 0x40); so = o + n * 55 + 4; vo = so + u32(raw, so - 4) * 16 + 4; si = vi = 0; states = []
    for t in range(n):
        b = raw[o + t * 55:o + (t + 1) * 55]
        for selector in range(b[46] + b[47]):
            s = raw[so + si * 16:so + (si + 1) * 16]; f = raw[vo + vi * 12:vo + (vi + 1) * 12]; nv = struct.unpack_from('<b', s, 13)[0]
            if t == 91:
                assert nv == 1, 'template 91 view count'
                states.append(dict(selector=selector, resource=struct.unpack_from('<h', f)[0], left=-s[14] / 2 + f[5], right=s[14] / 2 - f[7], bottom=f[8], state_height=s[15], top_trim=f[6], height_flags=b[50], frame_flags=f[2], state_hex=s.hex(), view_hex=f.hex()))
            si += 1; vi += 1 if nv < 0 else nv
    assert [s['resource'] for s in states] == [28, 27], 'template 91 resources'
    sections_ = h.sections(blob); frames = []; files = {}
    for d in [27, 28]:
        v = struct.unpack_from('<6H11I', blob, sections_[2] + d * 56); pos = sections_[3] + v[7]
        for frame in range(v[4]):
            size = v[12] if v[3] == 0x28e else 8 + struct.unpack_from('<H', blob, pos + 6)[0]; w, hh, pix, _ = h.decode_rows(blob[pos:pos + size], v[3]); assert (w, hh) == v[1:3], 'chain frame extent'
            name = f'chain_{d}_{frame}.png'; files[name] = png_l(w, hh, pix, h.Image)
            frames.append(dict(resource=d, frame=frame, path=name, source_offset=pos, source_sha256=sha(blob[pos:pos + size]), png_sha256=sha(files[name]))); pos += size
        assert pos == sections_[3] + v[8], 'chain sequence end'
    props = []
    for i in range(85, 109):
        b = geo[u32(geo, 0x14) + 37 * i:][:37]; assert struct.unpack_from('<H', b, 32)[0] == 91, ('support template', i)
        x, y, z = (struct.unpack_from('<h', b, j)[0] for j in [0, 2, 6]); region = struct.unpack_from('<H', b, 10)[0]; r = geo[u32(geo, 0xc) + region * 44:][:44]; floor, ceil = struct.unpack_from('<hh', r, 20); s = states[1]
        # verify_prop_region_height.selected_height(flags, True, floor, ceil, state_height)
        selected = h.region_height(floor, ceil) if s['height_flags'] & 2 else s['state_height'] & 255
        top = selected - s['top_trim']; props.append(dict(record=i, position=[x, z, -y], region=region, left=s['left'], right=s['right'], bottom=s['bottom'], top=top, raw_hex=b.hex()))
    files['chains.json'] = (json.dumps(dict(geometry_sha256=sha(geo), assembly_sha256=sha(raw), cache_sha256=CAVE_BLOB_SHA, states=states, props=props, frames=frames, scope='Original source bounds and pixels. Static selector1 and breaking selector0 identified by artwork; animation rate and billboarding authored.'), indent=2) + '\n').encode()
    # Earlier preview names of the frame-0 images (same decode, same bytes).
    files['chain_27.png'] = files['chain_27_0.png']; files['chain_28.png'] = files['chain_28_0.png']
    return files


def river_regions(mix, h):
    """export_river_regions.py, unchanged apart from readers."""
    u32 = h.u32
    entries, entry, raw, verts, records, regions = decode(mix, h); e = entries[0]; meta = mix[e['offset']:e['offset'] + e['size']]; start, count = u32(meta, 4), u32(meta, 0x3c); names = start + count * 24
    assert names + count * 22 == u32(meta, 8), 'preset names'
    selected = [i for i in range(count) if meta[names + i * 22:names + (i + 1) * 22].split(b'\0')[0] == b'Rapids']; assert len(selected) == 1, 'Rapids preset'
    rows = []
    for i, r in enumerate(records):
        if r[14] & 0x20 and not r[14] & 0x80: continue
        if (r[16] & 255) != selected[0]: continue
        floor = struct.unpack_from('<h', bytes.fromhex(regions[i]['raw_hex']), 20)[0]
        rows.append(dict(region=i, polygon=[[verts[v][0] / 65536, -verts[v][1] / 65536] for v in regions[i]['vertex_indices']], floor=floor, raw_hex=regions[i]['raw_hex']))
    assert len(rows) == 37 and all(r['floor'] == -395 for r in rows), 'Rapids regions'
    return {'regions.json': (json.dumps(dict(geometry_sha256=sha(raw), preset=selected[0], regions=rows, scope='Recovered X/-Y footprints and native floor height. Liquid surface, flow direction/speed and damage are not inferred.'), indent=2) + '\n').encode()}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    if overlaps(a.output_root, a.game): p.error(f'--output-root overlaps input {a.game}')
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if sha((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    try:
        from types import SimpleNamespace
        from lol2_source_format import parse_mix
        from build_game_atlas import u32
        from lol2_material_format import sections, material_record, column_major_to_rows, png_rgb
        from lol2_creature_sprite_format import decode_rows
        from map_props import region_height
        import map_materials
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    h = SimpleNamespace(parse_mix=parse_mix, u32=u32, sections=sections, material_record=material_record, column_major_to_rows=column_major_to_rows,
                        png_rgb=png_rgb, decode_rows=decode_rows, region_height=region_height, Image=Image)
    mix = (a.game / 'DAT/L1_DC.MIX').read_bytes()
    with tempfile.TemporaryDirectory(prefix='river-deck-') as tmp:
        try:
            map_materials.export_materials(a.game, 'L1_DC', Path(tmp) / 'materials')
            blob = (Path(tmp) / 'materials/texture.bin').read_bytes(); assert sha(blob) == CAVE_BLOB_SHA, 'cave texture blob'
            files = {**catalogue(mix, blob, h), **chains(mix, blob, h), **river_regions(mix, h)}
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, TypeError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    out = a.output_root / PACK; out.mkdir(parents=True)
    for name, data in sorted(files.items()): (out / name).write_bytes(data)
    print('PASS river_deck: deck records 6, chain supports 24, chain frames', sum(1 for n in files if n.startswith('chain_') and n.count('_') == 2),
          'Rapids regions 37, files', len(files))


if __name__ == '__main__':
    main()
