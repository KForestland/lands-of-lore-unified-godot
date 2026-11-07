#!/usr/bin/env python3
"""Prepare Cave door placements, motion and textures from original game data."""
import argparse
import json
import struct
from pathlib import Path
from build_game_atlas import parse_mix, u32
from lol2_rotation_table import rotation_table
from export_map_movables import _box_faces
from prepare_jungle_followup_gate_media import model, require, sha
from lol2_material_format import material_record, column_major_to_rows, rgb_palette, colorize, png_rgb


def prepare(game, texture, output):
    require(not output.exists(), 'Output must be fresh')
    for source in (game, texture):
        require(output != source and output not in source.parents and source not in output.parents, 'Output overlaps input')
    archive = (game / 'DAT/L1_DC.MIX').read_bytes()
    require(sha(archive) == '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345', 'Unsupported Cave archive')
    entries = {e['key']: e for e in parse_mix(archive)}
    def entry(key):
        e = entries[key]
        return archive[e['offset']:e['offset'] + e['size']]
    raw, meta = entry(2971673856), entry(2971019266)
    exe = (game / 'LOLG.DAT').read_bytes()
    require(sha(exe) == 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775', 'Unsupported executable')
    blob = texture.read_bytes()
    require(sha(blob) == '102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97', 'Unsupported Cave texture')
    trig = struct.unpack('<4096i', rotation_table(game))
    to, nt = u32(meta, 12), u32(meta, 0x44)
    placements, doors = [], []
    for index in (75, 79):
        d = raw[u32(raw, 0x24) + index * 41:][:41]
        x, y, heading, z = struct.unpack_from('<hhHh', d)
        template_id = d[32]
        template = meta[to + template_id * 60:][:60]
        require(template[50] == 1, 'Door child count differs')
        first = sum(meta[to + i * 60 + 50] for i in range(template_id))
        child = meta[to + nt * 60 + 4 + first * 60:][:60]
        resources = [struct.unpack_from('<h', child, i * 8)[0] for i in range(6)]
        require(set(resources) == {0, 85, 470}, 'Door materials differ')
        bounds = struct.unpack_from('<4b2B', child, 52)
        width, depth = template[47:49]
        corner = (-(width // 2) << 16, (depth // 2) * (1 if d[33] == 1 else -1) << 16)
        anchor = (x << 16, y << 16)
        pivot = model(corner, anchor, heading, trig)
        frames = []
        for step in range(101):
            progress = (d[36] * 2 * 65536 // 360) * step // 100
            angle = (heading + (-progress if d[33] & 1 else progress)) & 65535
            position = model(tuple(-v for v in corner), pivot, angle, trig)
            surfaces = []
            for face, points in enumerate(_box_faces(bounds)):
                if not resources[face]:
                    continue
                vertices = []
                for lx, lz, ly in points:
                    wx, wy = model((lx << 16, ly << 16), position, angle, trig)
                    vertices.append([(wx - anchor[0]) / 65536, lz, (wy - anchor[1]) / 65536])
                surfaces.append(dict(face=face, material=resources[face], vertices=vertices))
            frames.append(surfaces)
        doors.append(dict(index=index, frames=frames, pivot=[(pivot[0] - anchor[0]) / 65536, 0, (pivot[1] - anchor[1]) / 65536]))
        placements.append(dict(index=index, template=template_id, native_xyz=[x, y, z], heading=heading, fixed_xyz=[x << 16, y << 16, z << 16], floor_review_position=[x / 64, z / 64, -y / 64], raw_hex=d.hex()))
    # These check counts/scope preserve the historical native report, not a new replay.
    report = dict(executable_sha256=sha(exe), geometry_sha256=sha(raw), code_sha256=sha(exe[0xae99a + 0x37000:0xae9ce + 0x37000]), placements=placements, checks=2, mismatches=0, scope='Native base-constructor XYZ slice. Floor review maps X,Z,-Y at1/64, an existing display convention. Runtime floor adjustment/collision not executed.')
    po = u32(blob, 4)
    palette = rgb_palette(blob[po:po + 768], 6)
    images = {}
    for index in (85, 470):
        mip = material_record(blob, index, allow_partial_mips=True)['mips'][0]
        w, h = mip['width'], mip['height']
        rows = column_major_to_rows(blob[mip['data_start']:mip['data_start'] + w * h], w, h)
        images[f'material_{index}.png'] = png_rgb(w, h, colorize(rows, palette))
        images[f'indices_{index}.png'] = png_rgb(w, h, bytes(c for value in rows for c in (value, value, value)))
    out = output / 'assets/lol2/doors'
    out.mkdir(parents=True)
    for name, data in images.items():
        (out / name).write_bytes(data)
    (out / 'placement.json').write_text(json.dumps(report, indent=2) + '\n')
    (out / 'motion.json').write_text(json.dumps(dict(doors=doors), separators=(',', ':')) + '\n')
    print('Prepared two doors, 202 poses and four material images')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('game', 'texture', 'output-root'):
        p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    try:
        prepare(a.game.resolve(), a.texture.resolve(), a.output_root.resolve())
    except (ValueError, OSError, KeyError, IndexError, struct.error) as error:
        p.error(str(error))


if __name__ == '__main__':
    main()
