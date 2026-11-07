#!/usr/bin/env python3
"""Prepare the existing Museum sword-transfer pack from originals and a fresh Museum texture."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix, u32
from lol2_creature_sprite_format import sections, rgb_palette, group_frames, lcw, decode_blocks, decode_rows
from lol2.map_props import load_templates


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require(value, message):
    if not value:
        raise ValueError(message)


def prepare(game, texture, output):
    require(not output.exists(), 'Output must be a fresh directory')
    for path in [game, texture]:
        require(output != path and output not in path.parents and path not in output.parents, 'Output overlaps input')
    pins = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac',
            'GLOBAL.MIX': '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd',
            'LOCAL.MIX': 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278'}
    archives = {name: (game / name).read_bytes() for name in pins}
    for name, wanted in pins.items():
        require(sha(archives[name]) == wanted, 'Unsupported original: ' + name)
    def entry(name, key):
        arc = archives[name]
        matches = [e for e in parse_mix(arc) if e['key'] == key]
        require(len(matches) == 1, 'Expected one archive entry')
        e = matches[0]
        return arc[e['offset']:e['offset'] + e['size']]
    arc = archives['DAT/L3_DH.MIX']
    candidates = [arc[e['offset']:e['offset'] + e['size']] for e in parse_mix(arc)
                  if e['size'] >= 80 and arc[e['offset']:e['offset'] + 8] == struct.pack('<II', 18, 516)]
    require(len(candidates) == 1, 'Expected one metadata entry')
    template = load_templates(candidates[0])['templates'][39]
    bases = [s['frames'][0]['descriptor'] for s in template['selectors']]
    require(bases == [1070, 1082, 1130, 1383], 'Template39 selector bindings differ')
    blob = texture.read_bytes()
    require(sha(blob) == '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07', 'Unsupported Museum texture')
    sec = sections(blob)
    descriptors = {}
    for base in bases:
        first = struct.unpack_from('<6H11I', blob, sec[2] + base * 56)
        for resource in range(base, base + (first[4] & 255)):
            descriptors[resource] = struct.unpack_from('<6H11I', blob, sec[2] + resource * 56)
    groups = group_frames(descriptors)
    require([g['count'] for g in groups] == [12, 6, 21, 31], 'Animation group sizes differ')
    palette = rgb_palette(blob[u32(blob, 4):][:768], 6)
    images = {}
    for group in groups:
        for resource in group['frames']:
            d = descriptors[resource]
            require(d[3] == 0x1246, 'Unsupported frame format')
            payload = blob[sec[3] + d[7]:sec[3] + d[7] + d[12]]
            ci = u32(payload, 8)
            require(sec[9] + ci * 12 + 12 <= min(o for o in sec[:14] if o > sec[9]), 'Codebook directory bounds')
            offset, allocation, packed = struct.unpack_from('<3I', blob, sec[9] + ci * 12)
            require(sec[8] <= offset <= offset + allocation <= sec[9] and packed <= allocation, 'Codebook bounds')
            w, h, pixels, _, _ = decode_blocks(payload, lcw(blob[offset:offset + packed]))
            require((w, h) == d[1:3], 'Frame dimensions')
            im = Image.frombytes('P', (w, h), pixels)
            im.putpalette(palette)
            images['frame_%d.png' % resource] = im
    definitions = entry('GLOBAL.MIX', 3984507021)
    require(sha(definitions) == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891', 'Definitions differ')
    start, count = u32(definitions, 4), u32(definitions, 0x34)
    states = start + count * 91 + 4
    views = states + u32(definitions, states - 4) * 16 + 4
    si = vi = 0
    sword_resource = None
    for index in range(count):
        record = definitions[start + index * 91:][:91]
        for selector in range(record[46] + record[47]):
            n = max(1, struct.unpack_from('<b', definitions, states + si * 16 + 13)[0])
            if index == 5 and selector == 0:
                require(u32(record, 24) == 0xe18240be and record[50] == 4 and n == 1, 'Sword definition differs')
                sword_resource = struct.unpack_from('<h', definitions, views + vi * 12)[0]
            si += 1
            vi += n
    require(sword_resource == 276, 'Sword view differs')
    graphics = entry('LOCAL.MIX', 4018716831)
    require(sha(graphics) == '36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93', 'Graphics entry differs')
    gs = sections(graphics)
    d = struct.unpack_from('<6H11I', graphics, gs[2] + sword_resource * 56)
    w, h, pixels, _ = decode_rows(graphics[gs[3] + d[7]:][:d[12]], allow_special=True)
    require((w, h) == d[1:3], 'Sword dimensions')
    palette = rgb_palette(graphics[u32(graphics, 4):][:768], 6)
    sword = Image.frombytes('RGBA', (w, h), bytes(c for i in pixels for c in (*palette[i*3:i*3+3], 0 if i in (0, 1) else 255)))
    rendering = dict(source_indices_sha256=sha(pixels), omitted_destination_remap_pixels=pixels.count(1),
                     visible_color_pixels=sum(i > 1 for i in pixels),
                     scope='Original ordinary palette colors preserved. Index0 transparent; index1 destination-remap pixels omitted, not recolored. Background-remap shadow remains unimplemented in this Sprite3D preview.')
    geo = entry('DAT/L3_DH.MIX', 3106551060)
    prop = geo[u32(geo, 0x14) + 107 * 37:][:37]
    require(struct.unpack_from('<H', prop, 32)[0] == 39, 'Prop107 template differs')
    item = geo[u32(geo, 0x20) + 11 * 37:][:37]
    require(u32(item, 32) == 0xe18240be, 'Item11 sword identity differs')
    region = struct.unpack_from('<22H', geo, u32(geo, 12) + 1265 * 44)
    polygon = [[v / 65536 for v in struct.unpack_from('<ii', geo, u32(geo, 4) + i * 8)] for i in region[6:10]]
    sequence = dict(groups={str(g['base']): g['frames'] for g in groups}, trigger_polygon=polygon, source_region=1265,
                    scope='Source route, sprite identities and placement endpoint. Authored8fps/3second walk, hand anchors, camera-facing orientation, alpha preview. Source region1265 entry used as one-shot reconstruction trigger; native collision/events not reproduced. Completed pose uses selector2 view0 first7 frames as authored idle loop.')
    out = output / 'assets/lol2/generated/museum_sword_transfer'
    out.mkdir(parents=True)
    for name, im in images.items():
        im.save(out / name, transparency=0)
    sword.save(out / 'sword.png')
    for name, data in [('sword_rendering.json', rendering), ('sequence.json', sequence)]:
        (out / name).write_text(json.dumps(data, indent=2) + '\n')
    return len(images) + 3


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game', 'texture', 'output-root']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        count = prepare(args.game.resolve(), args.texture.resolve(), args.output_root.resolve())
    except (ValueError, OSError, KeyError) as error:
        parser.error(str(error))
    print('PASS Museum sword-transfer files:', count)


if __name__ == '__main__':
    main()
