#!/usr/bin/env python3
"""Pin the water-gate/oil/fire puzzle and stage its original sprites and hut movie."""
import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path

from verify_actor_item_grants import source_area, GAME
from build_game_atlas import parse_mix, section
from prepare_jungle_exit_encounter import predicate
from lol2 import map_props as props
from lol2.map_surfaces import source_tables, resolve_resource, floor_uv
from lol2.map_video_inventory import lookup_movie
from lol2_movie_media import decode, audio
from prepare_jungle_exit_movies import parse_vqa_chunks

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('/home/bob/lol2_out/all_maps_20260922/L4_HJ')
IDS = [427, 561, *range(562, 573), 1486]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    assert not args.output_root.exists(), 'Use a fresh output root'
    out = args.output_root / 'assets/lol2/generated/jungle_chief_hut'
    out.mkdir(parents=True)
    area, arc, entry, raw, owners, streams = source_area('L4_HJ')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    selected = []
    for row in owners:
        if ((row['owner_kind'] == 'prop' and row['owner'] in IDS)
            or (row['owner_kind'] == 'control' and row['owner'] in [96, 97])
            or row['group'] in [4050, 7320, 7422, 7938, 4442]):
            selected.append(dict(row, commands=streams[row['stream']][row['group']],
                                 predicate_expression=predicate(table, row['predicate']) if row['predicate'] is not None else None))
    assert {14086, 14260, 15708, 15736, 19760, 20216, 21120, 4442} <= {r['group'] for r in selected}
    geo = json.loads((MAP / 'geometry/geometry.json').read_text())
    def region(n):
        r = geo['regions'][n]
        return dict(id=n, polygon=[[geo['vertices_fixed'][v][0]/65536, -geo['vertices_fixed'][v][1]/65536] for v in r['vertex_indices']],
                    floor_min=min(r['floor_corners']), floor_max=max(r['floor_corners']))
    _, _, placements = section(raw, 0x14, 0x60, 37)
    _, _, controls = section(raw, 0x18, 0x64, 33)
    def placement(blob, n, stride):
        r = blob[n*stride:(n+1)*stride]
        x, z, heading, y = struct.unpack_from('<hhHh', r)
        return dict(id=n, position=[x,y,-z], heading=heading, raw=r.hex(), template=r[32])
    entries = parse_mix(arc)
    meta = next(e for e in entries if e['key'] == 3710142494)
    templates = props.load_templates(arc[meta['offset']:meta['offset']+meta['size']])['templates']
    tex = (MAP / 'materials/texture.bin').read_bytes()
    # The texture is already independently decoded/pinned by the existing material export.
    material_report = json.loads((MAP / 'materials/materials.json').read_text())
    assert hashlib.sha256(tex).hexdigest() == material_report['source_hash']['decoded_texture_sha256']
    sec = props.mm.sections(tex)
    palette_at = props.u32(tex, 4)
    rgb = props.mm.rgb_palette(tex[palette_at:palette_at+768], 6)
    sprite_dir = out / 'sprites'; sprite_dir.mkdir()
    cache = {}
    objects = []
    for n in IDS:
        obj = placement(placements, n, 37)
        obj['selectors'] = []
        if n != 561:
            for selector in templates[obj['template']]['selectors']:
                frame = selector['frames'][0]
                image = props.build_image(frame['descriptor'], tex, sec, rgb, sprite_dir, out, cache)
                obj['selectors'].append(dict(selector=selector['selector'], descriptor=frame['descriptor'],
                    frames=image.get('frames', [image['image']]), left=frame['left'], right=frame['right'],
                    bottom=frame['bottom'], top=selector['state_height']-frame['top_trim']))
        objects.append(obj)
    dynamic = sorted({int.from_bytes(bytes.fromhex(c['raw_hex'])[2:4], 'little') for r in selected for c in r['commands'] if bytes.fromhex(c['raw_hex'])[0] == 196})
    original = json.loads((ROOT / 'assets/lol2/generated/jungle_review/jungle.json').read_text())
    faces = [f for f in original['faces'] if f['kind'] == 'floor' and f['region'] in dynamic]
    preset_ids = {int.from_bytes(bytes.fromhex(c['raw_hex'])[6:8], 'little') for r in selected for c in r['commands'] if bytes.fromhex(c['raw_hex'])[0] == 204 and bytes.fromhex(c['raw_hex'])[4:6] == b'\xff\xff'}
    _, _, presets = source_tables(GAME, 'L4_HJ')
    preset_map = {}
    for n in sorted(preset_ids):
        resource, indirection = resolve_resource(presets[n]['resource'], tex)
        preset_map[str(n)] = dict(presets[n], resource=resource, indirection=indirection)
    material_ids = {str(f['material']) for f in faces} | {str(p['resource']) for p in preset_map.values()}
    materials = {}
    for key in sorted(material_ids):
        # Current Jungle pack already maps source material IDs to checked images.
        if key in original['materials']:
            name = original['materials'][key]
            shutil.copy2(ROOT / 'assets/lol2/generated/jungle_review' / name, out / Path(name).name)
            materials[key] = [Path(name).name]
        else:
            material = next(m for m in material_report['materials'] if m['index'] == int(key))
            name = 'material_%s.png' % key
            shutil.copy2(MAP / 'materials' / material['image'], out / name)
            materials[key] = [name]
    rotation = Path('/home/bob/lol2_out/draracle_rotation_table_2026-09-11/rotation_table.bin').read_bytes()
    assert hashlib.sha256(rotation).hexdigest() == 'd7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'
    trig = struct.unpack('<4096i', rotation)
    for face in faces:
        face['preset_uv'] = {}
        for n, preset in preset_map.items():
            material = next(m for m in material_report['materials'] if m['index'] == preset['resource'])
            face['preset_uv'][n] = floor_uv(face['points'], preset, material, trig)
    movie = lookup_movie(GAME, 'L4_HJ', 'HUT-FIRE.VQA')
    assert movie['status'] == 'exact' and movie['sha256'] == '2a20298e30d0d08e43f6a83d1ab2743432c55d4a5dd9c72fe11ceb30bfb11f30'
    movie_dir = out / 'movie'; movie_dir.mkdir()
    vqa = args.output_root / 'HUT-FIRE.VQA'; vqa.write_bytes(movie['blob'])
    h = movie['vqhd']; assert (h['count'],h['width'],h['height'],h['fps']) == (60,640,400,15)
    frames = decode(vqa, movie_dir, 60, (640,400))
    samples = sum(len(v)*2 for k,v in parse_vqa_chunks(movie['blob']) if k == b'SND2')
    rate = audio(vqa, movie_dir / 'voice.wav', samples) if samples else 0
    result = dict(version=1, source=area['source'], texture_sha256=hashlib.sha256(tex).hexdigest(),
                  records=selected, objects=objects, controls=[placement(controls,n,33) for n in [96,97]],
                  regions=[region(n) for n in [2147,3568,3657,3792,2443]],
                  dynamic_regions=dynamic, floor_faces=faces, materials=materials, presets=preset_map,
                  movie=dict(frames=[str(p.relative_to(out)) for p in frames], fps=15, duration=4.0,
                             sha256=movie['sha256'], audio='movie/voice.wav' if samples else '', rate=rate),
                  fire_order=[572,568,564,563,569,567,562,571,566,570,565],
                  adapters=dict(fire_step_seconds=2.0, surface_seconds=1.0, rock_seconds=0.4,
                                movie='Full original60-frame hut movie; completion drives source prop561 reverse-end outcome.'))
    (out / 'source.json').write_text(json.dumps(result, indent=2)+'\n')
    print('PASS chief hut:',len(selected),'records,',len(objects),'objects,',len(faces),'floor faces,60 movie frames')


if __name__ == '__main__': main()
