#!/usr/bin/env python3
"""Stage Museum item row 7, the source "56a-Ltng cr" (Lightning crystal) behind the rubble-room blocks.

L3_DH item row7: native (431,1416,5), flags 2 (active, dormant bit 0x1000 clear), region1010, identity 0x84D4248D ->
GLOBAL definition55 "56a-Ltng cr" (handler 8). Image: the definition's first-selector view resource, row decode, the
same walk as the Jungle world items. Pickup range/E and inventory presentation are modern; item handler 8 is not replayed.
"""
from pathlib import Path
import argparse, hashlib, json, struct, sys
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lol2_source_format import parse_mix, u32
from lol2_material_format import sections, rgb_palette
from lol2_creature_sprite_format import decode_rows
ARCHIVES = [('DAT/L3_DH.MIX', 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'),
            ('GLOBAL.MIX', '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
            ('LOCAL.MIX', 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]
ROW, IDENTITY, DEFINITION, NAME = 7, 0x84D4248D, 55, '56a-Ltng cr'
digest = lambda raw: hashlib.sha256(raw).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    game, root = args.game.resolve(), args.output_root.resolve()
    if root.exists(): parser.error('Output must be a fresh directory')
    if root == game or root in game.parents or game in root.parents: parser.error('Output overlaps original game')
    try:
        raw = {}
        for name, wanted in ARCHIVES:
            raw[name] = (game / name).read_bytes()
            if digest(raw[name]) != wanted: raise ValueError('Unsupported original ' + name)
        def entry(name, key):
            found = [e for e in parse_mix(raw[name]) if e['key'] == key]
            if len(found) != 1: raise ValueError('Expected one source entry')
            return raw[name][found[0]['offset']:found[0]['offset'] + found[0]['size']]
        level = entry('DAT/L3_DH.MIX', 3106551060)
        if digest(level) != 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7': raise ValueError('Museum geometry changed')
        record = level[u32(level, 0x20) + 37 * ROW:][:37]
        x, y, _, z = struct.unpack_from('<hhHh', record)
        flags, region = struct.unpack_from('<HH', record, 8)
        if (x, y, z, flags, region, u32(record, 32)) != (431, 1416, 5, 2, 1010, IDENTITY): raise ValueError('Item row7 changed')
        d = entry('GLOBAL.MIX', 3984507021)
        if digest(d) != 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891': raise ValueError('Definitions changed')
        base, count = u32(d, 4), u32(d, 0x34)
        state = base + count * 91 + 4; view = state + u32(d, state - 4) * 16 + 4; names = view + u32(d, view - 4) * 12
        resource = None; si = vi = 0
        for index in range(count):
            rec = d[base + index * 91:][:91]
            for selector in range(rec[46] + rec[47]):
                views = max(1, struct.unpack_from('<b', d, state + si * 16 + 13)[0])
                if index == DEFINITION and selector == 0: resource = struct.unpack_from('<h', d, view + vi * 12)[0]
                si += 1; vi += views
        rec = d[base + DEFINITION * 91:][:91]
        name = d[names + DEFINITION * 30:names + DEFINITION * 30 + 24].split(b'\0')[0].decode()
        if u32(rec, 24) != IDENTITY or name != NAME or resource is None: raise ValueError('Definition55 changed')
        graphics = entry('LOCAL.MIX', 4018716831)
        if digest(graphics) != '36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93': raise ValueError('Graphics changed')
        sec = sections(graphics); desc = struct.unpack_from('<6H11I', graphics, sec[2] + resource * 56)
        width, height, pixels, _ = decode_rows(graphics[sec[3] + desc[7]:][:desc[12]], allow_special=True)
        if (width, height) != desc[1:3]: raise ValueError('Image size mismatch')
        palette = rgb_palette(graphics[u32(graphics, 4):][:768], 6)
        rgba = bytes(c for p in pixels for c in (*palette[p * 3:p * 3 + 3], 0 if p in (0, 1) else 255))
        out = root / 'assets/lol2/generated/museum_lightning_crystal'; out.mkdir(parents=True)
        Image.frombytes('RGBA', (width, height), rgba).save(out / 'crystal.png')
        item = dict(id='museum:item7:Lightning_Crystal', row=ROW, name=NAME, position=[x, z, -y], native_position=[x, y, z],
                    flags=flags, region=region, identity=IDENTITY, definition=DEFINITION, handler=rec[0x42], resource=resource,
                    size=[width, height], placement_hex=record.hex())
        (out / 'items.json').write_text(json.dumps(dict(version=1, items=[item], level_sha256=digest(level), definitions_sha256=digest(d),
            graphics_sha256=digest(graphics), pixels_sha256=digest(pixels),
            scope='Source active placement row7 and definition55 inventory image. Pickup range/E are modern; handler 8 (use) not replayed.'), indent=1) + '\n')
        print('Verified Lightning crystal row7 resource', resource, 'image', width, height)
    except (OSError, ValueError, KeyError, struct.error) as error:
        parser.error(str(error) or type(error).__name__)

if __name__ == '__main__':
    main()
