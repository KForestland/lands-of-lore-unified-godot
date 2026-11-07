#!/usr/bin/env python3
"""Stage the Museum "Sludge" floor pack (preset 17 -> resource 21) from explicit original game files.

  python3 tools/prepare_museum_sludge_floor.py --game GAME --review assets/lol2/generated/museum_review/museum.json \
      --output-root FRESH

The published museum_review pack textures a floor only when its resolved material is in the 2026-09-13 runtime capture
set; resource 21 was not captured, so its 47 floors (Long arm pit 167-176/204-220/240, sludge chute 953-967, duct
corridor 1368-1370/1428-1463) are drawn in the review's debug colour. This tool decodes resource 21 with the published
readers (map_materials export, raw_variant family, 10 variants) and computes each floor's UVs with the same preset
surface formula as tools/build_museum_review.py. The formula is verified against every textured floor of the published
review before any sludge UV is written. Images use the capture orientation of material 111 (same column_major_raw
family, transposed). The 8 fps playback rate is the review's authored rate for material 111, a modern adapter; the native
phase clock is unverified. No historical export, RE checkout or native replay.
"""
import argparse, hashlib, json, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'}
ROTATION_SHA256 = 'd7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'
RESOURCE, PRESET_NAME, FACE_COUNT, FPS = 21, 'Sludge', 47, 8.0
PACK = 'assets/lol2/generated/museum_sludge_floor'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'review', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    output = a.output_root.resolve()
    for original in [a.game, a.review]:
        original = original.resolve()
        if output == original or output in original.parents or original in output.parents: p.error('--output-root overlaps an input')
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    import map_geometry, map_materials, map_surfaces
    from lol2_rotation_table import rotation_table
    from lol2_material_format import png_rgb
    from PIL import Image
    review = json.loads(a.review.read_text())
    with tempfile.TemporaryDirectory(prefix='museum-sludge-') as tmp:
        tmp = Path(tmp)
        try:
            map_geometry.export_geometry(a.game, 'L3_DH', tmp / 'geometry')
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            g = json.loads((tmp / 'geometry/geometry.json').read_text())
            _, _, presets = map_surfaces.source_tables(a.game, 'L3_DH')
            blob = (tmp / 'materials/texture.bin').read_bytes()
            mats = {m['index']: m for m in json.loads((tmp / 'materials/materials.json').read_text())['materials']}
            table_data = rotation_table(a.game)
            assert digest(table_data) == ROTATION_SHA256, 'rotation table changed'
            table = struct.unpack('<4096i', table_data)

            def trig(angle):
                angle &= 65535; return table[(angle & 32767) >> 3] * (-1 if angle >= 32768 else 1)

            def surface_uv(region, preset, size):
                # Same arithmetic as tools/build_museum_review.py surface_uv (initial flags 0).
                x0 = presets[preset]; aa, bb = trig(x0['angle']), trig(x0['angle'] + 16384); scale = x0['scale']
                uv = []
                for v in region['vertex_indices']:
                    x, y = g['vertices_fixed'][v]; x -= x0['offset_x']; y -= x0['offset_y']
                    u = (((y * bb) >> 16) + ((x * aa) >> 16)) * scale / 65536 + x0['offsets'][0]
                    vv = (((x * bb) >> 16) - ((y * aa) >> 16)) * scale / 65536 + x0['offsets'][1]
                    uv.append([u / size[0], vv / size[1]])
                return uv

            floors = {f['region']: f for f in review['faces'] if f['kind'] == 'floor'}
            checked, sludge = 0, {}
            for r in g['regions']:
                if r['floor_subdivisions']: continue
                sel = struct.unpack('<22H', bytes.fromhex(r['raw_hex']))[16] & 255
                if sel == 255 or sel >= len(presets): continue
                k, _ = map_surfaces.resolve_resource(presets[sel]['resource'], blob)
                face = floors.get(r['id'])
                assert face is not None, ('review lacks floor', r['id'])
                if face['material'] == 'unresolved':
                    assert k == RESOURCE and presets[sel]['name'] == PRESET_NAME, ('unexpected unresolved floor', r['id'], k)
                    m = mats[k]; sludge[str(r['id'])] = surface_uv(r, sel, (m['width'], m['height']))
                else:
                    # Formula witness: the published UVs of every textured floor.
                    assert int(face['material']) == k, ('material differs', r['id'])
                    m = mats[k]; want = face['uv']; got = surface_uv(r, sel, (m['width'], m['height']))
                    assert all(abs(x - y) < 1e-9 for pa, pb in zip(got, want) for x, y in zip(pa, pb)), ('UV formula differs', r['id'])
                    checked += 1
            assert len(sludge) == FACE_COUNT, ('sludge floor count', len(sludge))
            m = mats[RESOURCE]
            assert m['family'] == 'raw_variant' and m.get('source_pixel_layout') == 'column_major_raw' and len(m['animation_frames']) == 10, 'resource 21 family differs'
            out = a.output_root / PACK; out.mkdir(parents=True)
            frames = []
            for index, name in enumerate(m['animation_frames']):
                im = Image.open(tmp / 'materials/material_0021' / name).convert('RGB').transpose(Image.Transpose.TRANSPOSE)
                data = png_rgb(im.size[0], im.size[1], im.tobytes()); filename = f'frame_{index}.png'
                (out / filename).write_bytes(data); frames.append(dict(path=filename, sha256=digest(data)))
        except (AssertionError, ValueError, KeyError, OSError, IndexError, TypeError) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
    manifest = dict(version=1, material=str(RESOURCE), preset=PRESET_NAME, width=m['width'], height=m['height'], fps=FPS,
                    frames=frames, uv=sludge, uv_formula_checked_floors=checked, originals=ORIGINALS,
                    scope='Resource 21 raw_variant frames in material 111 capture orientation; floor UVs from the review preset '
                          'surface formula, verified on every textured review floor. 8 fps is the authored material-111 rate '
                          '(modern adapter); native phase clock unverified.')
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print('PASS museum_sludge_floor:', len(sludge), 'floors,', checked, 'formula witnesses,', len(frames), 'frames')


if __name__ == '__main__':
    main()
