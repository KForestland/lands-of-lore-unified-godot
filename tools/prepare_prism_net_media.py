#!/usr/bin/env python3
"""Prepare the complete existing Prism and Net of Exile image packs."""
import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path
from PIL import Image
from lol2 import map_props as props
from lol2_source_format import u32
from prepare_museum_key_locks import icon

CONTRACTS = {
    'museum_prism_source.json': 'fec400711ae361b6daed8850c87666869c7125a0d043edb2cf13b9144262faac',
    'museum_prism_panorama.json': 'da93f7946af3a131b098b19eb2eb0298625344efb683e63ca42beb8ce7d43255',
    'hive_net_exile_source.json': '4c428d7bb944f57efe21c6494be005a859bfb79d7847106198e65e209bf69dae',
}
TEXTURES = {
    'museum_prism': '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07',
    'hive_net_exile': 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def prepare(game, museum_texture, hive_texture, contracts, output):
    require(not output.exists(), 'Output must be a fresh directory')
    for path in (game, museum_texture, hive_texture, contracts):
        require(path.exists(), f'Missing input: {path}')
        require(output != path and output not in path.parents and path not in output.parents,
                f'Output overlaps input: {path}')
    records = {}
    for name, pin in CONTRACTS.items():
        raw = (contracts / name).read_bytes()
        require(sha(raw) == pin, f'Unsupported contract: {name}')
        records[name] = json.loads(raw)
    blobs = dict(museum_prism=museum_texture.read_bytes(), hive_net_exile=hive_texture.read_bytes())
    for pack, blob in blobs.items():
        require(sha(blob) == TEXTURES[pack], f'Unsupported texture: {pack}')
    for pack, descriptor, display, definition, icon_name in (
            ('museum_prism', 440, 'display.png', 7, 'icon.png'),
            ('hive_net_exile', 229, 'pile.png', 25, 'net.png')):
        contract = records[pack + '_source.json']
        tex = blobs[pack]
        out = output / 'assets/lol2/generated' / pack
        scratch = output / 'tmp' / pack
        out.mkdir(parents=True)
        (scratch / 'sprites').mkdir(parents=True)
        sections = props.mm.sections(tex)
        palette = props.mm.rgb_palette(tex[u32(tex, 4):][:768], 6)
        image = props.build_image(descriptor, tex, sections, palette, scratch / 'sprites', scratch, {})
        decoded = scratch / image.get('frames', [image['image']])[0]
        want = contract['images'][display] if pack == 'museum_prism' else contract['sprite']['sha256']
        require(sha(decoded.read_bytes()) == want, f'{pack}: display hash differs')
        shutil.copyfile(decoded, out / display)
        icon(definition, out / icon_name, game=game)
        if pack == 'museum_prism':
            require(sha((out / icon_name).read_bytes()) == contract['images'][icon_name], 'Prism icon differs')
            panels = records['museum_prism_panorama.json']['panels']
            require({p['descriptor'] for p in panels} == set(range(424, 431)), 'Panorama selections differ')
            for panel in panels:
                descriptor_id = panel['descriptor']
                v = struct.unpack_from('<6H11I', tex, sections[2] + descriptor_id * 56)
                payload = tex[sections[3] + v[7]:sections[3] + v[7] + v[12]]
                require(sha(payload) == panel['payload_sha256'], 'Panorama payload differs')
                flags, width, height, size = struct.unpack_from('<4H', payload)
                require(flags == 0x8f and size == len(payload) - 8 and
                        (width, height) == (panel['width'], panel['height']), 'Panorama shape differs')
                pixels, _ = props.mm.decode_column_payload(payload[8:], width, height)
                rgba = bytes(c for k in pixels for c in (*palette[k * 3:k * 3 + 3], 255 if k else 0))
                Image.frombytes('RGBA', (width, height), rgba).save(out / panel['image'])
    return {'museum_prism': 9, 'hive_net_exile': 2}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('game', 'museum-texture', 'hive-texture', 'contracts', 'output-root'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        result = prepare(args.game.resolve(), args.museum_texture.resolve(), args.hive_texture.resolve(),
                         args.contracts.resolve(), args.output_root.resolve())
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
