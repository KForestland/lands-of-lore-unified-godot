#!/usr/bin/env python3
"""Prepare the existing Hive nest movie/pose pack from explicit source inputs.

Uses original movie/state records and fresh Hive geometry. Existing selector
choices and authored billboard anchors are preserved, not re-proven natively.
"""
import argparse
import hashlib
import json
import struct
import subprocess
from pathlib import Path
from PIL import Image
import numpy as np
from lol2.map_video_inventory import lookup_movie
from lol2_source_format import parse_mix
from lol2_creature_sprite_format import parse_states, lcw, decode_blocks
from lol2_material_format import sections, rgb_palette
ARCHIVE_SHA = 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
TEXTURE_SHA = 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game', 'geometry', 'texture', 'output-root']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    output = args.output_root.resolve()
    if output.exists():
        parser.error('--output-root must be fresh')
    for root in [args.game, args.geometry.parent, args.texture.parent, Path(__file__).parent]:
        root = root.resolve()
        if output == root or output in root.parents or root in output.parents:
            parser.error('Output overlaps input directory')
    G = args.game.resolve()
    archive = (G / 'DAT/L5_HC.MIX').read_bytes()
    if sha(archive) != ARCHIVE_SHA:
        parser.error('Unsupported Hive archive')
    if sha(args.texture.read_bytes()) != TEXTURE_SHA:
        parser.error('Unsupported Hive texture')
    geometry = json.loads(args.geometry.read_text())
    if geometry['source'].get('area_id') != 'L5_HC' or geometry['source'].get('sha256') != ARCHIVE_SHA:
        parser.error('Wrong Hive geometry source')
    ge = next((e for e in parse_mix(archive) if e['key'] == 3776990464))
    raw = archive[ge['offset']:ge['offset'] + ge['size']]
    if sha(raw) != geometry['source'].get('geometry_sha256'):
        parser.error('Wrong geometry entry binding')
    approaches = []
    for index in [1006, 1009, 1010, 1015, 1071, 1072]:
        r = geometry['regions'][index]
        approaches.append(dict(region=index, polygon=[[geometry['vertices_fixed'][v][0] / 65536, -geometry['vertices_fixed'][v][1] / 65536] for v in r['vertex_indices']], floor=min(r['floor_corners']), ceiling=max(r['ceiling_corners'])))
    out = output / 'assets/lol2/generated/hive_nest'
    cache = output / 'tmp/hive_nest'
    out.mkdir(parents=True)
    cache.mkdir(parents=True)
    rows = []
    for name, stem, count, pin in [('EX07.VQA', 'nesting', 36, 'a1d6fbf7cc02e82ea6d8c45e0184b3005d473f5849b30eb72e3e4df0c81245e0'), ('EX08.VQA', 'nest_to_attack', 28, '2106b4a283888bd4f800af230a32595d039e3fb93bc34ceb055300b855d2e498')]:
        r = lookup_movie(G, 'L5_HC', name)
        assert r['sha256'] == pin
        path = cache / name
        path.write_bytes(r['blob'])
        p = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-an', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'], capture_output=True, check=True)
        (cache / (stem + '.log')).write_bytes(p.stderr)
        pixels = p.stdout
        assert len(pixels) == count * 320 * 200 * 3
        sheet = Image.new('RGB', (2560, 200 * ((count + 7) // 8)))
        for i in range(count):
            sheet.paste(Image.frombytes('RGB', (320, 200), pixels[i * 192000:(i + 1) * 192000]), (i % 8 * 320, i // 8 * 200))
        rgb = np.array(sheet)
        key = rgb[0, 0].copy()
        assert tuple(key) == (0, 251, 251)
        alpha = np.where(np.all(rgb == key, axis=2), 0, 255).astype('uint8')
        Image.fromarray(np.dstack((rgb, alpha))).save(out / (stem + '_atlas.png'))
        rows.append({'file': stem + '_atlas.png', 'frames': count, 'columns': 8, 'fps': 15, 'source_sha256': pin, 'atlas_sha256': sha((out / (stem + '_atlas.png')).read_bytes())})
    archive = (G / 'DAT/L5_HC.MIX').read_bytes()
    assert sha(archive) == 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
    entry = next((e for e in parse_mix(archive) if e['key'] == 3776335874))
    entity = parse_states(archive[entry['offset']:entry['offset'] + entry['size']])['entities'][1]
    assert entity['name'] == 'EXEC'
    state = entity['states'][0]
    assert state['views'][0]['resource_reference'] == 688
    b = args.texture.read_bytes()
    assert sha(b) == 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
    s = sections(b)
    po = struct.unpack_from('<I', b, 4)[0]
    pal = rgb_palette(b[po:po + 768], 6)
    v = struct.unpack_from('<6H11I', b, s[2] + 688 * 56)
    payload = b[s[3] + v[7]:s[3] + v[7] + v[12]]
    ci = struct.unpack_from('<I', payload, 8)[0]
    offset, allocation, packed = struct.unpack_from('<3I', b, s[9] + ci * 12)
    book = lcw(b[offset:offset + packed])
    w, h, pixels, used, tail = decode_blocks(payload, book)
    rgba = bytes((c for x in pixels for c in (*pal[x * 3:x * 3 + 3], 255 if x else 0)))
    Image.frombytes('RGBA', (w, h), rgba).save(out / 'executioner.png')
    pose = dict(name='EXEC', resource=688, file='EXEC_688.png', state=state, payload_sha256=sha(payload), codebook=ci, codebook_sha256=sha(book), unread_tail_bytes=tail)
    u32 = lambda at: struct.unpack_from('<I', raw, at)[0]

    def position(field, index, stride):
        x, y, h, z = struct.unpack_from('<hhHh', raw, u32(field) + index * stride)
        return [x, z, -y]
    p = u32(28) + 36 * 56
    assert raw[p + 32] == 1
    assert entity['states'][2]['views'][0]['resource_reference'] == 433
    result = dict(archive_sha256=sha(archive), nest=position(20, 317, 37), actor=position(28, 36, 56), nest_size=[125, 78], actor_size=[90, 56], nest_baseline=135, actor_baseline=176, movies=rows, approaches=approaches, actor_pose=pose, actor_binding=dict(actor=36, source_offset=ge['offset'] + p, definition=1, name='EXEC', initial_selector=0, first_resources=[688]), native_completion_selector=2, native_completion_resource=433, actor_png_sha256=sha((out / 'executioner.png').read_bytes()), scope='Original64 movie frames, exact RGB background-key preview, source positions and six approach polygons. Ground alignment uses first nest frame opaque baseline135 and actor baseline176, an authored preview anchor. Static recovered EXEC selector0 pose is a presentation fixture; native combat and movie scheduling parity are not claimed.')
    (out / 'nest.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Prepared64nest movie frames,EXEC pose and6approach polygons')
if __name__ == '__main__':
    main()
