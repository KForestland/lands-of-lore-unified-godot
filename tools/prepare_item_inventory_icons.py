#!/usr/bin/env python3
"""Stage the original 24x24 inventory icons of all carriable LoL2 item definitions.

The item record's selector 0 / view 0 resource (prepare_item_definitions.py, items/icons/) is the GROUND sprite
(LOCAL descriptor flags 0x28E): the flat picture of an item lying in the world. The inventory uses separate
24x24 resources with flags 0x48E in the same LOCAL.MIX graphics entry 4018716831 (audit_20261028/ITEMS_AUDIT s3).

Payload layout of a 0x48E resource:
  +0  sprite header (0x048E, 24, 24, size)        +8  sub-header (0, 0x18, 0x18, 0) + u16 size
  +16 u16 unpacked size                            +18 LCW stream, relative mode (leading 0x00; long copies count
                                                       back from the output end)
The LCW output is a zero-run RLE image (00 n = n transparent pixels, any other byte = one pixel) of exactly
24*24 pixels. Palette and transparency (indices 0 and 1) are those of the ground sprites.

Link (PROVEN for 164 definitions): the LOCAL descriptor u32 field 6 is a source tag shared by an item's ground sprite
and its inventory icon. "1-Stalagmite" (definition 0) has no shared tag; its icon is resource 23, beside ground
sprite 24 (likely, longplay 6:12 picture match) -> listed in ADJACENT. Ghost rows 152..156 are never carried and get
no icon here (their picture-only candidates are recorded in the JSON, not staged). The native draw call that picks
the icon is not traced.

Reads, from an explicit original game root: GLOBAL.MIX entry 3984507021 (item definitions) and LOCAL.MIX entry
4018716831 (graphics), both SHA-256 pinned. Writes (generated, never committed - original media):
  <output-root>/assets/lol2/generated/items/inventory_icons/NNN.png   one per carriable definition (165)
  <output-root>/assets/lol2/generated/items/inventory_icons.json      definition -> resource, link evidence, sha
Deterministic: PNGs are written with fixed settings and no metadata; the JSON has no timestamps.

Usage: python3 tools/prepare_item_inventory_icons.py --game /path/to/LoL2 [--output-root PROJECT]
"""
import argparse, hashlib, json, struct, sys, zlib
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
from lol2_source_format import parse_mix, u32  # noqa: E402
from lol2_creature_sprite_format import sections, rgb_palette  # noqa: E402

GLOBAL_SHA = 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
LOCAL_SHA = '36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
COUNT = 170
ICON_FLAGS, SIZE = 0x48E, 24
GHOSTS = range(152, 157)
## Definition -> icon resource where the tag link does not apply (evidence in the docstring).
ADJACENT = {0: 23}
## Ghost rows: picture-only candidates (never carried, not staged).
GHOST_CANDIDATES = {153: 28, 154: 31, 155: 30}
EXPECTED_ICONS = 165


def sha(b): return hashlib.sha256(b).hexdigest()


def fail(message): raise SystemExit(f'FAIL {message}')


def lcw_relative(src, limit):
    if not src or src[0] != 0: fail('LCW stream is not in relative mode')
    out, pos = bytearray(), 1

    def take(n):
        nonlocal pos
        if pos + n > len(src): fail('Truncated LCW command')
        data = src[pos:pos + n]; pos += n
        return data

    start = 0
    while pos < len(src):
        start = len(out)
        if start >= limit: fail('LCW commands continue past the declared size')
        cmd = take(1)[0]
        if cmd == 0x80: fail('Unexpected LCW terminator')
        if cmd & 0xc0 == 0x80: out += take(cmd & 63)
        elif cmd == 0xfe:
            n = struct.unpack('<H', take(2))[0]; out += take(1) * n
        else:
            if cmd < 0x80:
                n = (cmd >> 4) + 3; ref = len(out) - (((cmd & 15) << 8) | take(1)[0])
            else:
                n = struct.unpack('<H', take(2))[0] if cmd == 0xff else (cmd & 63) + 3
                ref = len(out) - struct.unpack('<H', take(2))[0]
            if not 0 <= ref < len(out): fail('Invalid LCW reference')
            for j in range(n): out.append(out[ref + j])
    # The stream has no 0x80 terminator: it ends with the file, and the last copy may run past the declared size
    # (23 of 165 icons by 1-3 bytes); the surplus is cut, as the declared size bounds the output.
    if not start < limit <= len(out): fail('LCW output length differs from the declared size')
    return bytes(out[:limit])


def zero_rle(stream, total):
    out, i = bytearray(), 0
    while i < len(stream):
        if stream[i] == 0:
            if i + 1 >= len(stream): fail('Truncated zero run')
            out += b'\0' * stream[i + 1]; i += 2
        else:
            out.append(stream[i]); i += 1
    if len(out) != total: fail('RLE does not give exactly 24x24 pixels')
    return bytes(out)


def png(width, height, rgba):
    rows = b''.join(b'\0' + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    def chunk(kind, data): return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


def build(game: Path):
    def entry(name, key):
        arc = (game / name).read_bytes()
        e = next((x for x in parse_mix(arc) if x['key'] == key), None)
        if e is None: fail(f'{name} entry {key} missing')
        return arc[e['offset']:][:e['size']]

    raw = entry('GLOBAL.MIX', 3984507021)
    if sha(raw) != GLOBAL_SHA: fail('GLOBAL.MIX item definitions changed')
    gfx = entry('LOCAL.MIX', 4018716831)
    if sha(gfx) != LOCAL_SHA: fail('LOCAL.MIX graphics changed')
    base, n = u32(raw, 4), u32(raw, 0x34)
    if n != COUNT: fail('Unexpected definition count')
    st = base + n * 91 + 4; vw = st + u32(raw, st - 4) * 16 + 4; nm = vw + u32(raw, vw - 4) * 12
    sec = sections(gfx); pal = rgb_palette(gfx[u32(gfx, 4):][:768], 6)
    count = (sec[3] - sec[2]) // 56
    desc = {r: struct.unpack_from('<6H11I', gfx, sec[2] + r * 56) for r in range(count)}
    icons = {r: d for r, d in desc.items() if d[3] == ICON_FLAGS}
    by_tag = {}
    for r, d in icons.items(): by_tag.setdefault(d[6], []).append(r)

    def decode(r):
        d = icons[r]
        data = gfx[sec[3] + d[7]:][:d[12]]
        flags, w, h, size = struct.unpack_from('<4H', data)
        if (flags, w, h) != (ICON_FLAGS, SIZE, SIZE) or size != len(data) - 8: fail(f'Icon {r} header')
        unpacked = struct.unpack_from('<H', data, 16)[0]
        pixels = zero_rle(lcw_relative(data[18:], unpacked), SIZE * SIZE)
        rgba = bytes(c for p in pixels for c in (*pal[p * 3:p * 3 + 3], 0 if p in (0, 1) else 255))
        return pixels, rgba

    rows, images, si, vi = [], {}, 0, 0
    for i in range(n):
        d = raw[base + i * 91:][:91]
        name = raw[nm + i * 30:nm + i * 30 + 24].split(b'\0')[0].decode('latin1')
        ground = None
        for s in range(d[46] + d[47]):
            views = max(1, struct.unpack_from('<b', raw, st + si * 16 + 13)[0])
            if s == 0: ground = struct.unpack_from('<h', raw, vw + vi * 12)[0]
            si += 1; vi += views
        row = dict(index=i, name=name, ground_resource=ground, resource=None, link='')
        if i in GHOSTS:
            row.update(link='ghost row: never carried, not staged', picture_candidate=GHOST_CANDIDATES.get(i))
        elif i in ADJACENT:
            row.update(resource=ADJACENT[i], link='adjacent resource (no shared tag; longplay 6:12 picture match)')
        else:
            if ground is None or ground <= 0 or ground not in desc: fail(f'Definition {i} has no ground sprite')
            found = by_tag.get(desc[ground][6], [])
            if len(found) != 1: fail(f'Definition {i} ({name}) links to {len(found)} icons')
            row.update(resource=found[0], link='descriptor tag shared with the ground sprite')
        if row['resource'] is not None:
            pixels, rgba = decode(row['resource'])
            images[i] = png(SIZE, SIZE, rgba)
            row.update(size=[SIZE, SIZE], pixels_sha256=sha(pixels),
                       path=f'res://assets/lol2/generated/items/inventory_icons/{i:03d}.png')
        rows.append(row)
    if len(images) != EXPECTED_ICONS: fail(f'Expected {EXPECTED_ICONS} icons, got {len(images)}')
    data = dict(version=1, sources=dict(global_sha256=GLOBAL_SHA, local_sha256=LOCAL_SHA), count=COUNT,
                staged=len(images), icon_resources=len(icons), definitions=rows)
    return data, images


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--game', type=Path, required=True)
    ap.add_argument('--output-root', type=Path, default=TOOLS.parent)
    a = ap.parse_args()
    for name in ('GLOBAL.MIX', 'LOCAL.MIX'):
        if not (a.game / name).is_file(): fail(f'{name} not found under {a.game}')
    data, images = build(a.game)
    out = a.output_root / 'assets/lol2/generated/items'
    (out / 'inventory_icons').mkdir(parents=True, exist_ok=True)
    for i, blob in images.items(): (out / 'inventory_icons' / f'{i:03d}.png').write_bytes(blob)
    (out / 'inventory_icons.json').write_text(json.dumps(data, indent=1) + '\n')
    shared = len({r['resource'] for r in data['definitions'] if r['resource'] is not None})
    print(f'PASS {len(images)} inventory icons ({shared} distinct resources of {data["icon_resources"]})')


if __name__ == '__main__':
    main()
