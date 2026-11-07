#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/wall_review pack (walls.json, material_K_variant_V.png, material_K.png)
and the dependent assets/lol2/generated/wall_indices pack (material_K.png, palette.png, manifest.json) from explicit
original game files.

  python3 tools/prepare_cave_walls_media.py --game GAME --output-root FRESH

The legacy chain (RE build_wall_review.py -> run_geometry_pipeline.py wall verifiers, extract_wall_texture_review.py,
export_flat_wall_uvs.py; then export_wall_index_textures.py; all unchanged) replays the native wall routine with
capstone to produce six wall-span groups, and each verifier asserts that replay equals its own independent pure model.
This tool computes the six groups with those independent models, unchanged, and runs the texture extraction, UV export,
staging and index export logic unchanged, in memory:
- L1_DC geometry with the pinned decode checks (lol2_source_format.parse_mix, build_game_atlas.u32,
  lol2_geometry_format.s16 / slope_corners);
- the cave texture blob from lol2/map_materials.export_materials(L1_DC) (texture.bin = the pinned cave cache blob);
- lol2_material_format.sections / rgb_palette / colorize / png_rgb / column_major_to_rows.
material_K.png in wall_review are the earlier staging name of material_K_variant_0.png for the single-variant
descriptors; they are written as the same bytes. The output root must be fresh and must not equal, contain or lie
inside the game root. Nothing is written until every stage passes. No historical export, RE checkout, native replay,
executable or capstone.
"""
import argparse, collections, hashlib, io, json, math, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L1_DC.MIX': '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'}
GEO_KEY = 0xB1202500
CAVE_BLOB_SHA = '102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'  # lol2_extract_cave_materials.HASH
WALL_BASE, REGION_BASE = 30093, 54509
REVIEW, INDICES = 'assets/lol2/generated/wall_review', 'assets/lol2/generated/wall_indices'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def require(condition, message):
    if not condition: raise ValueError(message)


def decode(mix, h):
    """lol2_extract_draracle_geometry.decode with its pinned checks: (raw, verts, records)."""
    require(sha(mix) == ORIGINALS['DAT/L1_DC.MIX'], 'L1_DC.MIX')
    e = next(e for e in h.parse_mix(mix) if e['key'] == GEO_KEY); raw = mix[e['offset']:e['offset'] + e['size']]
    require(h.u32(raw, 0) == 18, 'format marker')
    nv, nr, vo, ro = h.u32(raw, 0x50), h.u32(raw, 0x58), h.u32(raw, 4), h.u32(raw, 12)
    require((nv, nr, vo, ro) == (2695, 1954, 5300, REGION_BASE), 'pinned geometry header')
    verts = list(struct.iter_unpack('<ii', raw[vo:vo + nv * 8]))
    records = [struct.unpack_from('<22H', raw, ro + i * 44) for i in range(nr)]
    for r in records:
        require(not any(x >= nv for x in r[6:10]), 'vertex reference')
        require(not any(x != 65535 and x >= nr for x in r[2:6]), 'region reference')
    return raw, verts, records


def upper_lower_model(r, n, c, offset, mode, s16):
    """lol2_verify_upper_lower_walls.model, unchanged."""
    floor, ceiling = s16(r[10]), s16(r[11])
    if c & 12 == 0: return max(floor, s16(n[11])), ceiling, offset
    top = s16(n[10]); difference = top - ceiling
    if r[17] & 255 != 255 and difference > 0:
        top = ceiling; offset = (offset + (difference >> ((mode - 1) & 31))) & 255
    return floor, top, offset


def span_groups(raw, verts, records, s16, slope_corners):
    """The six verifier groups, each from its independent model (the value its native replay is asserted to equal)."""
    wall = lambda index: raw[WALL_BASE + index * 8:WALL_BASE + index * 8 + 8]
    quad = lambda p0, p1, high, low: [[p0[0], high[0] * 65536, p0[1]], [p1[0], high[1] * 65536, p1[1]], [p1[0], low[1] * 65536, p1[1]], [p0[0], low[0] * 65536, p0[1]]]
    groups = {k: [] for k in ['flat_wall_spans', 'upper_lower_walls', 'sloped_middle_walls', 'sloped_upper_lower_walls', 'connector_middle_walls', 'special_upper_lower_walls']}
    for rid, r in enumerate(records):  # lol2_verify_flat_wall_spans
        for index in range(r[13], r[13] + (r[15] & 255)):
            d = wall(index); c = d[5] & 31; edge = c & 3; neighbor = r[2 + edge]; nr = records[neighbor] if neighbor != 65535 else None
            if c & 12 not in [4, 12] or r[14] & 0xbc or (nr and nr[14] & 0x9c): continue
            low = s16(r[10]); high = s16(r[11])
            if nr: low = max(low, s16(nr[10])); high = min(high, s16(nr[11]))
            p0, p1 = [verts[r[6 + k]] for k in [edge, (edge + 1) % 4]]
            groups['flat_wall_spans'].append(dict(record=index, region=rid, points_fixed=quad(p0, p1, [high] * 2, [low] * 2), active=p0 != p1 and low < high))
    for rid, r in enumerate(records):  # lol2_verify_upper_lower_walls
        for index in range(r[13], r[13] + (r[15] & 255)):
            d = wall(index); c = d[5] & 31; nid = r[2 + (c & 3)]
            if c & 12 not in [0, 8]: continue
            if nid == 65535: continue
            n = records[nid]
            if r[14] & 0xfc or n[14] & 0xfc: continue
            low, high, uv = upper_lower_model(r, n, c, d[3], d[7] & 3, s16); edge = c & 3; p0, p1 = [verts[r[6 + k]] for k in [edge, (edge + 1) % 4]]
            groups['upper_lower_walls'].append(dict(record=index, region=rid, points_fixed=quad(p0, p1, [high] * 2, [low] * 2), active=low < high))
    for rid, r in enumerate(records):  # lol2_verify_sloped_middle_walls
        for index in range(r[13], r[13] + (r[15] & 255)):
            d = wall(index); c = d[5] & 31; edge = c & 3; nid = r[2 + edge]; nr = records[nid] if nid != 65535 else None
            if c & 12 not in [4, 12] or r[14] & 0xf0 or (nr and nr[14] & 0xf0): continue
            if not (r[14] | (nr[14] if nr else 0)) & 12: continue
            low = slope_corners(records, rid); high = slope_corners(records, rid, True)
            if not r[14] & 12 and nr:
                low = [max(s16(r[10]), s16(nr[10]))] * 4; high = [min(s16(r[11]), s16(nr[11]))] * 4
            j = (edge + 1) % 4; p0, p1 = [verts[r[6 + k]] for k in [edge, j]]
            groups['sloped_middle_walls'].append(dict(record=index, region=rid, points_fixed=quad(p0, p1, [high[edge], high[j]], [low[edge], low[j]]), active=p0 != p1 and (low[edge] < high[edge] or low[j] < high[j])))
    for rid, r in enumerate(records):  # lol2_verify_sloped_upper_lower_walls
        for index in range(r[13], r[13] + (r[15] & 255)):
            d = wall(index); c = d[5] & 31; edge = c & 3; nid = r[2 + edge]
            if c & 12 not in [0, 8]: continue
            if nid == 65535: continue
            nr = records[nid]
            if r[14] & 0xf0 or nr[14] & 0xf0: continue
            if not (r[14] | nr[14]) & 12: continue
            j = (edge + 1) % 4; indices = [edge, j]; offset = d[3]; mode = d[7] & 3
            low, high, uv = upper_lower_model(r, nr, c, offset, mode, s16)
            if c & 12 == 0:
                high = [slope_corners(records, rid, True)[k] for k in indices]; low = [low] * 2; neighbor_slope = bool(nr[14] & 8)
            else:
                low = [slope_corners(records, rid)[k] for k in indices]; high = [high] * 2; neighbor_slope = bool(nr[14] & 4)
            if neighbor_slope:
                matches = [k for k, v in enumerate(nr[6:10]) if v == r[6 + edge]]
                if len(matches) != 1 or nr[6 + (matches[0] + 3) % 4] != r[6 + j]: continue
                k = matches[0]; corners = slope_corners(records, nid, c & 12 == 0)
                heights = [corners[k], corners[(k + 3) % 4]]
                if c & 12 == 0: low = heights
                else: high = heights
            p0, p1 = [verts[r[6 + k]] for k in indices]
            groups['sloped_upper_lower_walls'].append(dict(record=index, region=rid, points_fixed=quad(p0, p1, high, low), active=low[0] < high[0] or low[1] < high[1]))
    for rid, r in enumerate(records):  # lol2_verify_connector_middle_walls
        for index in range(r[13], r[13] + (r[15] & 255)):
            d = wall(index); c = d[5] & 31; edge = c & 3; nid = r[2 + edge]; nr = records[nid] if nid != 65535 else None
            if c & 12 not in [4, 12] or not ((r[14] | (nr[14] if nr else 0)) & 16): continue
            require(not (r[14] | (nr[14] if nr else 0)) & 0xec, 'connector flags')
            j = (edge + 1) % 4; p0, p1 = [verts[r[6 + k]] for k in [edge, j]]
            low = [s16(r[10])] * 4; high = [s16(r[11])] * 4
            if nr and nr[14] & 16:
                k = 0 if nr[2] == rid else 2
                if d[6] & 128: low = [s16(nr[10])] * 4; high = [s16(nr[11])] * 4
                if c & 12 == 4: p1 = verts[nr[6 + k + 1]]
                else: p0 = verts[nr[6 + k]]
            elif nr:
                low = [max(s16(r[10]), s16(nr[10]))] * 4; high = [min(s16(r[11]), s16(nr[11]))] * 4
            groups['connector_middle_walls'].append(dict(record=index, region=rid, points_fixed=quad(p0, p1, [high[edge], high[j]], [low[edge], low[j]]), active=p0 != p1 and (low[edge] < high[edge] or low[j] < high[j])))
    for rid, r in enumerate(records):  # lol2_verify_special_upper_lower_walls
        for index in range(r[13], r[13] + (r[15] & 255)):
            d = wall(index); c = d[5] & 31; edge = c & 3; nid = r[2 + edge]; nr = records[nid] if nid != 65535 else None
            if c & 12 not in [0, 8] or nr is None: continue
            if not (r[14] | nr[14]) & 0xf0: continue
            require(not (r[14] | nr[14]) & 0xcc, 'special flags')
            j = (edge + 1) % 4; p0, p1 = [verts[r[6 + k]] for k in [edge, j]]
            if nr[14] & 16 and d[6] & 128:
                k = 0 if nr[2] == rid else 2
                p0, p1 = verts[nr[6 + k + 1]], verts[nr[6 + k]]
            low, high, uv = upper_lower_model(r, nr, c, d[3], d[7] & 3, s16)
            groups['special_upper_lower_walls'].append(dict(record=index, region=rid, points_fixed=quad(p0, p1, [high] * 2, [low] * 2), active=low < high))
    return groups


def wall_textures(raw, records, blob, h):
    """extract_wall_texture_review.py, unchanged apart from in-memory PNGs."""
    uses = collections.defaultdict(list)
    for rid, r in enumerate(records):
        for index in range(r[13], r[13] + (r[15] & 255)):
            k = struct.unpack_from('<h', raw, WALL_BASE + index * 8)[0]; require(k >= 0, 'Animated reference requires separate binding')
            uses[k].append(dict(record=index, region=rid))
    s = h.sections(blob); end = min(x for x in s if x > s[3]); pal = struct.unpack_from('<I', blob, 4)[0]
    rgb = h.rgb_palette(blob[pal:pal + 768], 6)
    results = []; pngs = {}
    for k, recs in sorted(uses.items()):
        v = struct.unpack_from('<6H11I', blob, s[2] + k * 56); ident, w, hh, flags, variants, field = v[:6]; mips = field & 255
        require(1 <= mips <= 5 and variants > 0, 'Invalid descriptor dimensions')
        images = []; reason = None
        for level in range(mips):
            width, height = max(1, w >> level), max(1, hh >> level); offset, size = v[7 + level], v[12 + level]
            if size != 8 + width * height: reason = 'Non-raw payload size'; break
            start = s[3] + offset; require(s[3] <= start and start + variants * size <= end, 'Payload extent')
            if level + 1 < mips: require(offset + variants * size == v[8 + level], 'Variant/mip boundary')
            for variant in range(variants):
                pos = start + variant * size
                require(struct.unpack_from('<4H', blob, pos) == (flags, width, height, (width * height) & 65535), 'Raw mip header')
                data = blob[pos + 8:pos + size]
                images.append((dict(level=level, variant=variant, width=width, height=height, source_offset=pos, pixels_sha256=sha(data)), data))
        if reason: continue
        metadata = []
        for im, data in images:
            stem = f'variant_{im["variant"]}_mip_{im["level"]}'
            png = f'material_{k:04d}/{stem}.png'
            pngs[png] = h.png_rgb(im['width'], im['height'], h.colorize(h.column_major_to_rows(data, im['width'], im['height']) if flags in [0xa9, 0x80a9] else data, rgb))
            im['preview_layout'] = 'column-major corrected' if flags in [0xa9, 0x80a9] else 'row-major unverified'
            im['png'] = png; metadata.append(im)
        results.append(dict(descriptor=k, flags=flags, variant_count=variants, records=recs, images=metadata))
    return dict(materials=results), pngs


def flat_wall_uvs(raw, groups, mats):
    """export_flat_wall_uvs.py report, unchanged (its preview cards and review.html are not part of the pack)."""
    lookup = {r['record']: m for m in mats['materials'] for r in m['records']}
    results = []; deferred = collections.Counter(); seen = set()
    for group in ['flat_wall_spans', 'upper_lower_walls', 'sloped_middle_walls', 'sloped_upper_lower_walls', 'connector_middle_walls', 'special_upper_lower_walls']:
        for row in groups[group]:
            k = row['record']; require(k not in seen, 'duplicate wall record'); seen.add(k); d = raw[WALL_BASE + k * 8:WALL_BASE + 8 + k * 8]; mat = lookup.get(k)
            if not row['active']: deferred['inactive'] += 1; continue
            if not mat: deferred['unsupported material'] += 1; continue
            pts = [[v / 65536 for v in p] for p in row['points_fixed']]
            sloped = pts[0][1] != pts[1][1] or pts[2][1] != pts[3][1]
            if pts[0][1] < pts[3][1] or pts[1][1] < pts[2][1]: deferred['crossing vertical boundaries'] += 1; continue
            length = math.dist(pts[0][::2], pts[1][::2]); height = max(pts[0][1], pts[1][1]) - min(pts[2][1], pts[3][1])
            if length == 0 or height <= 0: deferred['degenerate span'] += 1; continue
            mode = (d[6] >> 5) & 3; scale = [2., 1., .5, .25][d[7] & 3]; anchor, other = [(0, 1), (1, 0), (3, 2), (2, 3)][mode]; start, end = list(pts[anchor]), pts[other]; start[1] = max(pts[0][1], pts[1][1]) if mode < 2 else min(pts[2][1], pts[3][1]); dx, dz = (end[0] - start[0]) / length, (end[2] - start[2]) / length; vertical = -1 if mode < 2 else 1
            im = next(x for x in mat['images'] if x['level'] == 0 and x['variant'] == 0); w, hh = im['width'], im['height']
            addressing = 8 if d[6] & 16 else (16 if d[6] & 8 else 0)
            uscale = scale if addressing else w / length
            vscale = scale if addressing == 8 else hh / height
            uoffset = d[2] if addressing else 0; voffset = d[3] if addressing == 8 else 0
            uv = [[((pt[0] - start[0]) * dx + (pt[2] - start[2]) * dz) * uscale, (pt[1] - start[1]) * vertical * vscale] for pt in pts]
            require(all(math.isfinite(v) and v >= -1e-7 for pair in uv for v in pair), 'uv range')
            # Preserve pre-wrap values: wrapping vertex UVs would destroy interpolation.
            results.append(dict(record=k, region=row['region'], descriptor=mat['descriptor'], variant_count=mat["variant_count"], preview_layout=im.get("preview_layout", "unverified"), sloped=sloped, orientation=mode, addressing=addressing, texels_per_unit=[uscale, vscale], points_godot=[[p[0], p[1], -p[2]] for p in pts], uv_unwrapped=[[(max(u, 0) + uoffset) / w, (max(v, 0) + voffset) / hh] for u, v in uv], dimensions=[w, hh], offset_bytes=list(d[2:4])))
    return dict(exported=len(results), verified_geometry_records=len(seen), geometry_unresolved=3052 - len(seen), deferred=dict(deferred), walls=results, scope='Diagnostic inferred world UVs, limited to non-crossing material spans; variants require manual review with three addressing modes; sloped UV anchors use upper/lower envelope. Unwrapped normalized UVs preserve repeats. No collision, transparency, camera or live rendering parity claim; generated files only.')


def index_textures(blob, review, h):
    """export_wall_index_textures.py, unchanged apart from reading the in-memory wall_review files."""
    s = h.sections(blob)
    palette_offset = struct.unpack_from('<I', blob, 4)[0]
    palette = h.rgb_palette(blob[palette_offset:palette_offset + 768], 6)
    walls = json.loads(review['walls.json'])['walls']
    files = {}; records = []
    for descriptor in sorted({int(w['descriptor']) for w in walls}):
        v = struct.unpack_from('<6H11I', blob, s[2] + descriptor * 56)
        width, height, flags = v[1:4]
        require(flags in (0xa9, 0x80a9, 0xc3, 0xe1, 0x80e1, 0x8b), 'Unknown preview layout')
        require(v[12] == 8 + width * height, 'Non-raw mip')
        pos = s[3] + v[7]
        require(struct.unpack_from('<4H', blob, pos) == (flags, width, height, (width * height) & 65535), 'Mip header changed')
        raw = blob[pos + 8:pos + v[12]]
        indices = h.column_major_to_rows(raw, width, height) if flags in (0xa9, 0x80a9) else raw
        # Independent parity with the already reviewed RGB texture prevents changing orientation, variant or palette.
        rgb = bytes(c for index in indices for c in palette[index * 3:index * 3 + 3])
        reference = h.Image.open(io.BytesIO(review[f'material_{descriptor}_variant_0.png'])).convert('RGB')
        require(reference.size == (width, height) and reference.tobytes() == rgb, 'Existing reviewed texture differs')
        stream = io.BytesIO(); h.Image.frombytes('L', (width, height), indices).save(stream, format='PNG'); files[f'material_{descriptor}.png'] = stream.getvalue()
        records.append(dict(descriptor=descriptor, width=width, height=height, row_major_indices_sha256=sha(indices), rgb_parity=True,
                            layout_scope="column-major" if flags in (0xa9, 0x80a9) else "existing row-major preview, native layout unverified"))
    stream = io.BytesIO(); h.Image.frombytes('RGB', (256, 1), palette).save(stream, format='PNG'); files['palette.png'] = stream.getvalue()
    report = dict(cache_sha256=CAVE_BLOB_SHA, walls=len(walls), materials=records,
                  scope='Original variant0 indices; exact RGB parity with current wall assets. Geometry, UVs and orientation unchanged. No runtime shade assignment.')
    files['manifest.json'] = (json.dumps(report, indent=2) + '\n').encode()
    return files


def build(mix, blob, h):
    raw, verts, records = decode(mix, h)
    groups = span_groups(raw, verts, records, h.s16, h.slope_corners)
    mats, pngs = wall_textures(raw, records, blob, h)
    walls = flat_wall_uvs(raw, groups, mats)
    # build_wall_review.py staging: walls.json plus every level-0 variant of the exported descriptors.
    review = {'walls.json': json.dumps(walls, indent=2).encode()}
    materials = {m['descriptor']: m for m in mats['materials']}
    for k in sorted({w['descriptor'] for w in walls['walls']}):
        for im in materials[k]['images']:
            if im['level'] == 0: review[f'material_{k}_variant_{im["variant"]}.png'] = pngs[im['png']]
        # Earlier staging name for single-variant descriptors (same bytes as variant 0).
        if materials[k]['variant_count'] == 1: review[f'material_{k}.png'] = review[f'material_{k}_variant_0.png']
    indices = index_textures(blob, review, h)
    return review, indices, walls, groups


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
        from lol2_geometry_format import s16, slope_corners
        from lol2_material_format import sections, rgb_palette, colorize, png_rgb, column_major_to_rows
        import map_materials
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    h = SimpleNamespace(parse_mix=parse_mix, u32=u32, s16=s16, slope_corners=slope_corners, sections=sections, rgb_palette=rgb_palette,
                        colorize=colorize, png_rgb=png_rgb, column_major_to_rows=column_major_to_rows, Image=Image)
    mix = (a.game / 'DAT/L1_DC.MIX').read_bytes()
    with tempfile.TemporaryDirectory(prefix='cave-walls-') as tmp:
        try:
            map_materials.export_materials(a.game, 'L1_DC', Path(tmp) / 'materials')
            blob = (Path(tmp) / 'materials/texture.bin').read_bytes(); require(sha(blob) == CAVE_BLOB_SHA, 'cave texture blob')
            review, indices, walls, groups = build(mix, blob, h)
        except (AssertionError, ValueError, KeyError, StopIteration, OSError, IndexError, TypeError, struct.error) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    for folder, files in [(REVIEW, review), (INDICES, indices)]:
        (a.output_root / folder).mkdir(parents=True)
        for name, data in sorted(files.items()): (a.output_root / folder / name).write_bytes(data)
    print('PASS cave walls: spans', {k: len(v) for k, v in groups.items()}, 'exported', walls['exported'], 'wall_review files', len(review), 'wall_indices files', len(indices))


if __name__ == '__main__':
    main()
