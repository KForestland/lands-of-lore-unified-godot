#!/usr/bin/env python3
"""Stage the Museum Prism panorama: the seven alcove wall records the prop280 pickup rewrites (docs/prism-effects.md).

Group6590's seven op204 commands (verify_prism_effect_sources.py) change wall records 1743/1744/1771/1745/1772/
1746/1747 from descriptors 430..424 to 871. 424..430 are 128x80 type-0x8F column textures forming a painted
panorama; 871 is 32x32 and fully index 0 (transparent). Their edges have neighbours, so the review geometry
(build_museum_review.py, no-neighbour walls only) never built them.

Outputs: assets/lol2/generated/museum_prism/panorama_<descriptor>.png (local, from the user's game files; never
published) and scripts/lol2/museum_prism_panorama.json (numbers only: quads, UVs, source pins).
Quads/UVs reuse build_museum_review.py's boundary-wall addressing (mode/anchor, addressing0 = stretch).
Column decoding and index-0 transparency follow extend_jungle_wall_materials.py (review interpretation).
"""
import hashlib, json, math, struct, sys
from pathlib import Path
from PIL import Image
from verify_hive_executioner import GAME
from verify_museum_panel import decode_columns

sys.path.insert(0, '/home/bob/lol2_re_publish_20260911/tools/draracle')
from lol2_cache_named_wall_fixture import load_named
from lol2_wall_material_checkpoint import sections
from lol2_palette_png import rgb_palette

ROOT = Path(__file__).resolve().parents[1]
GEOMETRY = Path('/home/bob/lol2_out/museum_geometry_20260913/geometry.json')
ASSET = 'sphere1\\l3_dh\\l3_dh.tex'
BLOB_SHA = '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07'


def main():
    checks = json.loads((ROOT / 'docs/prism-effect-checks.json').read_text())
    records = checks['panorama']['records']
    g = json.loads(GEOMETRY.read_text())
    archive = (GAME / 'DAT/L3_DH.MIX').read_bytes(); e = g['source']['entry']
    assert hashlib.sha256(archive).hexdigest() == g['source']['sha256']
    raw = archive[e['offset']:e['offset'] + e['size']]; assert hashlib.sha256(raw).hexdigest() == g['source']['entry_sha256']
    wall_start = struct.unpack_from('<I', raw, 8)[0]
    _, blob, _, _ = load_named(GAME, ASSET); assert hashlib.sha256(blob).hexdigest() == BLOB_SHA
    s = sections(blob); end = min(o for o in s if o > s[3]); po = struct.unpack_from('<I', blob, 4)[0]
    palette = rgb_palette(blob[po:po + 768], 6)

    def material(index):
        v = struct.unpack_from('<6H11I', blob, s[2] + index * 56); width, height, flags, variants = v[1:5]
        start, size = s[3] + v[7], v[12]; assert flags == 0x8f and variants == 1 and s[3] <= start < start + size <= end
        payload = blob[start:start + size]; w, h, pixels = decode_columns(payload); assert (w, h) == (width, height)
        return w, h, pixels, hashlib.sha256(payload).hexdigest()

    w, h, pixels, cleared_sha = material(871)
    assert (w, h) == (32, 32) and not any(pixels), 'descriptor 871 is not fully transparent'
    out = ROOT / 'assets/lol2/generated/museum_prism'; out.mkdir(parents=True, exist_ok=True)
    prop = json.loads((ROOT / 'scripts/lol2/museum_prism_source.json').read_text())['prop']
    centre = [prop['position'][0], prop['position'][2]]
    panels = []
    for r in records:
        region = g['regions'][r['region']]; d = raw[wall_start + r['wall_record'] * 8:wall_start + r['wall_record'] * 8 + 8]
        assert d.hex() == r['raw_hex'] and struct.unpack_from('<h', d)[0] == r['initial_descriptor']
        edge = d[5] & 3; assert d[5] & 4 and region['neighbors'][edge] is not None
        assert d[6] & 0x18 == 0 and (d[6] >> 5) & 3 == 0, 'only stretch addressing, mode 0 staged'
        i, j = edge, (edge + 1) % 4
        vi, vj = region['vertex_indices'][i], region['vertex_indices'][j]
        p = lambda v, hgt: [g['vertices_fixed'][v][0] / 65536, hgt, -g['vertices_fixed'][v][1] / 65536]
        pts = [p(vi, region['floor_corners'][i]), p(vj, region['floor_corners'][j]), p(vj, region['ceiling_corners'][j]), p(vi, region['ceiling_corners'][i])]
        # build_museum_review.py boundary mapping, mode 0 / addressing 0: u along v0->v1 over the length, v down from the top.
        top = max(q[1] for q in pts); height = top - min(q[1] for q in pts); length = math.dist(pts[0][::2], pts[1][::2])
        dx, dz = (pts[1][0] - pts[0][0]) / length, (pts[1][2] - pts[0][2]) / length
        uv = [[((q[0] - pts[0][0]) * dx + (q[2] - pts[0][2]) * dz) / length, (top - q[1]) / height] for q in pts]
        w, h, pixels, payload_sha = material(r['initial_descriptor'])
        rgba = bytes(c for k in pixels for c in (*palette[k * 3:k * 3 + 3], 255 if k else 0))
        name = f"panorama_{r['initial_descriptor']}.png"; Image.frombytes('RGBA', (w, h), rgba).save(out / name)
        # The panel faces the alcove: the Prism display stands on the inner side.
        mid = [(pts[0][0] + pts[1][0]) / 2, (pts[0][2] + pts[1][2]) / 2]; normal = [-dz, dx]
        inward = (centre[0] - mid[0]) * normal[0] + (centre[1] - mid[1]) * normal[1] > 0
        panels.append(dict(region=r['region'], wall_record=r['wall_record'], descriptor=r['initial_descriptor'], cleared_descriptor=r['new_descriptor'],
                           image=name, width=w, height=h, payload_sha256=payload_sha, points=pts, uv=uv, left_normal_inward=inward))
    result = dict(version=1, source=dict(archive='DAT/L3_DH.MIX', archive_sha256=g['source']['sha256'], geometry_sha256=g['source']['entry_sha256'],
                                         texture_blob_sha256=BLOB_SHA, cleared_descriptor=871, cleared_payload_sha256=cleared_sha),
                  scope='Shown while the Prism is on display; prop280 pickup (group6590 op204 x7) clears the panels to the transparent '
                        'descriptor 871. One-sided toward the alcove. Static mip0, index0 transparency, unshaded (adapters).',
                  panels=panels)
    (ROOT / 'scripts/lol2/museum_prism_panorama.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS museum prism panorama: {len(panels)} source panels staged, descriptor 871 transparent, faces toward alcove {[x["left_normal_inward"] for x in panels]}')


if __name__ == '__main__':
    main()
