#!/usr/bin/env python3
"""Original "38-Guard shield" (GLOBAL definition37, identity 0x9E689A13) icon, palette indices and defense byte.

Granted with a Short Sword to cave guards52/53 by prop699/group7878 (property1) and prop1067/group8908 (property4)
on arrival (opus/guard52_53_loot_20261009/grant_replay.json). Same decode as prepare_cave_captain_items.py.
Output: assets/lol2/generated/cave_guard_shield/{Guard_Shield.png,Guard_Shield_indices.png,shield.json}."""
import json, struct
from PIL import Image
from prepare_hive_wax import entry, sections, rgb_palette, decode_rows, ROOT, digest, u32

def main():
    definitions = entry('GLOBAL.MIX', 3984507021); graphics = entry('LOCAL.MIX', 4018716831)
    assert digest(definitions) == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    assert digest(graphics) == '36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
    base, n = u32(definitions, 4), u32(definitions, 0x34); so = base + n * 91 + 4; fo = so + u32(definitions, so - 4) * 16 + 4; names = fo + u32(definitions, fo - 4) * 12
    index = next(i for i in range(n) if definitions[names + i * 30:names + i * 30 + 24].split(b'\0')[0].decode() == '38-Guard shield')
    d = definitions[base + index * 91:][:91]; assert index == 37 and u32(d, 24) == 0x9E689A13 and d[46] + d[47] == 1
    # Resource of the single view (same per-definition view indexing as the captain items: views are one per definition here).
    resource = struct.unpack_from('<h', definitions, fo + index * 12)[0]; desc = struct.unpack_from('<6H11I', graphics, sections(graphics)[2] + resource * 56)
    sec = sections(graphics); palette = rgb_palette(graphics[u32(graphics, 4):][:768], 6)
    w, h, pixels, _ = decode_rows(graphics[sec[3] + desc[7]:][:desc[12]], allow_special=True); assert (w, h) == desc[1:3]
    out = ROOT / 'assets/lol2/generated/cave_guard_shield'; out.mkdir(parents=True, exist_ok=True)
    rgba = bytes(c for p in pixels for c in (*palette[p * 3:p * 3 + 3], 0 if p in (0, 1) else 255))
    Image.frombytes('RGBA', (w, h), rgba).save(out / 'Guard_Shield.png')
    Image.frombytes('L', (w, h), bytes(0 if p in (0, 1) else p for p in pixels)).save(out / 'Guard_Shield_indices.png')
    row = dict(name='38-Guard shield', definition=index, identity=0x9E689A13, resource=resource, size=[w, h], defense=struct.unpack_from('<b', d, 0x41)[0],
               definition_hex=d.hex(), pixels_sha256=digest(bytes(pixels)) if isinstance(pixels, (bytes, bytearray)) else digest(bytes(pixels)))
    (out / 'shield.json').write_text(json.dumps(row, indent=2) + '\n')
    print('PASS guard shield definition%d resource%d size%s defense%d' % (index, resource, (w, h), row['defense']))

if __name__ == '__main__':
    main()
