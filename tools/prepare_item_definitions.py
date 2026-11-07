#!/usr/bin/env python3
"""Stage all 170 original LoL2 item definitions and their inventory icons (items chunk 1).

Reads, from an explicit original game root, the GLOBAL.MIX item definition table (entry 3984507021), LOCAL.MIX
graphics (entry 4018716831) and LOLG.DAT (handler fixups). Every source is SHA-256 pinned.

Writes (generated, never committed — original media):
  <output-root>/assets/lol2/generated/items/definitions.json   all fields + raw 91-byte record per definition
  <output-root>/assets/lol2/generated/items/icons/NNN.png      first view of selector 0 (165 decodable)
and, with --docs, <output-root>/docs/item-definitions-source.json (fields only, no raw record bytes, no pixels).

Field layout (same reads as prepare_act_one_item_defenses.py, prepare_jungle_world_items.py, prepare_hive_wax.py):
  +24 identity, +0x3B mask word, +0x3F class byte, +0x41 signed defense, +0x42 handler index, +46/+47 selector counts,
  +50, +0x47 4 x (byte, word, word) descriptors. Handler index -> code VA via the LE fixup at slot 0xC860+4*index
  (prepare_hive_elevator.py walk). Other varying bytes are kept raw ("undecoded") and are not interpreted.
Class byte +0x3F: 0x44 hand weapons, 0x48 thrown/ranged, 0x50 shields/bracers, 0x60 body armour, 0x43 rings/amulets/
  gauntlets, 0x40 other. Agreement with every existing port slot is checked by tests/item_definitions_test.gd; the
  native reader of this byte is NOT traced, so the slot it implies is a documented adapter (docs/DEVIATIONS.md).

Usage: python3 tools/prepare_item_definitions.py --game /path/to/LoL2 [--output-root PROJECT] [--docs]
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
from lol2_source_format import parse_mix, u32  # noqa: E402
from lol2_creature_sprite_format import decode_rows, sections, rgb_palette  # noqa: E402
from prepare_cave_special_media import fixups  # noqa: E402

GLOBAL_SHA = 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
LOCAL_SHA = '36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
EXE_SHA = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
COUNT = 170
KNOWN = {24, 25, 26, 27, 0x3b, 0x3c, 0x3f, 0x41, 0x42, 46, 47, 50} | set(range(0x47, 0x5b))
CLASS_NAMES = {0x44: 'hand_weapon', 0x48: 'thrown', 0x50: 'shield_bracers', 0x53: 'shield_bracers', 0x60: 'body_armour',
               0x43: 'ring_amulet', 0x40: 'other'}


def sha(b): return hashlib.sha256(b).hexdigest()


def build(game: Path):
    from PIL import Image

    def entry(name, key):
        arc = (game / name).read_bytes()
        e = next(x for x in parse_mix(arc) if x['key'] == key)
        return arc[e['offset']:][:e['size']]

    raw = entry('GLOBAL.MIX', 3984507021)
    if sha(raw) != GLOBAL_SHA: raise SystemExit('GLOBAL.MIX item definitions changed')
    base, n = u32(raw, 4), u32(raw, 0x34)
    if n != COUNT: raise SystemExit('Unexpected definition count')
    st = base + n * 91 + 4; vw = st + u32(raw, st - 4) * 16 + 4; nm = vw + u32(raw, vw - 4) * 12
    gfx = entry('LOCAL.MIX', 4018716831)
    if sha(gfx) != LOCAL_SHA: raise SystemExit('LOCAL.MIX graphics changed')
    sec = sections(gfx); pal = rgb_palette(gfx[u32(gfx, 4):][:768], 6)
    exe = (game / 'LOLG.DAT').read_bytes()
    if sha(exe) != EXE_SHA: raise SystemExit('LOLG.DAT changed')
    le = 0x39024 + u32(exe, 0x39060); first = u32(exe, le + u32(exe, le + 0x40) + 108)
    pages = {}

    def handler_va(h):
        slot = 0xc860 + 4 * h; page = first - 1 + slot // 4096
        if page not in pages: pages[page] = fixups(exe, le, page)
        r = pages[page].get(slot % 4096)
        if r is None or r['target_object'] != 2: raise SystemExit(f'Handler {h} has no code fixup')
        return r['target_offset'] + 0x59024

    records = [raw[base + i * 91:][:91] for i in range(n)]
    varying = [o for o in range(91) if len({r[o] for r in records}) > 1]
    rows, icons = [], {}
    si = vi = 0
    for i, d in enumerate(records):
        name = raw[nm + i * 30:nm + i * 30 + 24].split(b'\0')[0].decode('latin1')
        resource = None
        for s in range(d[46] + d[47]):
            views = max(1, struct.unpack_from('<b', raw, st + si * 16 + 13)[0])
            if s == 0: resource = struct.unpack_from('<h', raw, vw + vi * 12)[0]
            si += 1; vi += views
        icon = None
        if resource is not None and resource > 0:
            desc = struct.unpack_from('<6H11I', gfx, sec[2] + resource * 56)
            payload = gfx[sec[3] + desc[7]:][:desc[12]]
            if len(payload) >= 8:
                w, h, px, _ = decode_rows(payload, allow_special=True)
                if (w, h) != desc[1:3]: raise SystemExit(f'Icon size mismatch for {i}')
                rgba = bytes(c for p in px for c in (*pal[p * 3:p * 3 + 3], 0 if p in (0, 1) else 255))
                icons[i] = Image.frombytes('RGBA', (w, h), rgba)
                icon = dict(resource=resource, size=[w, h], pixels_sha256=sha(px))
        label = name.split('-', 1)[1].strip() if '-' in name[:5] else name
        cls = d[0x3f]; h = d[0x42]
        rows.append(dict(index=i, name=name, label=label, identity=u32(d, 24), handler=h, handler_va=hex(handler_va(h)) if h else '',
                         mask=struct.unpack_from('<H', d, 0x3b)[0], item_class=cls, class_name=CLASS_NAMES.get(cls, 'unknown'),
                         defense=struct.unpack_from('<b', d, 0x41)[0], selectors=[d[46], d[47]], byte50=d[50],
                         descriptors=[r for r in ([d[0x47 + k], *struct.unpack_from('<HH', d, 0x4b + k * 4)] for k in range(4)) if any(r)],
                         undecoded={str(o): d[o] for o in varying if o not in KNOWN and d[o]}, icon=icon,
                         ghost=icon is None, record_sha256=sha(d), record_hex=d.hex()))
    if sum(1 for r in rows if r['icon']) != 165: raise SystemExit('Expected 165 decodable icons')
    if len({r['identity'] for r in rows}) != COUNT: raise SystemExit('Identities are not unique')
    data = dict(version=1, sources=dict(global_sha256=GLOBAL_SHA, local_sha256=LOCAL_SHA, exe_sha256=EXE_SHA),
                varying_record_offsets=varying, definitions=rows)
    return data, icons


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--game', type=Path, required=True)
    ap.add_argument('--output-root', type=Path, default=TOOLS.parent)
    ap.add_argument('--docs', action='store_true')
    a = ap.parse_args()
    data, icons = build(a.game)
    out = a.output_root / 'assets/lol2/generated/items'
    (out / 'icons').mkdir(parents=True, exist_ok=True)
    for i, image in icons.items():
        image.save(out / 'icons' / f'{i:03d}.png')
        data['definitions'][i]['icon']['path'] = f'res://assets/lol2/generated/items/icons/{i:03d}.png'
    (out / 'definitions.json').write_text(json.dumps(data, indent=1) + '\n')
    if a.docs:
        rows = [{k: v for k, v in r.items() if k not in ('record_hex', 'undecoded')} for r in data['definitions']]
        for r in rows:
            if r['icon']: r['icon'] = {k: v for k, v in r['icon'].items() if k != 'path'}
        doc = dict(version=1, sources=data['sources'], count=COUNT, decodable_icons=len(icons), definitions=rows,
                   scope='Original item definition fields and icon identities. Raw record bytes and pixels stay in the '
                         'generated folder. Class-byte slots are an adapter; undecoded stats are not used.')
        (a.output_root / 'docs/item-definitions-source.json').write_text(json.dumps(doc, indent=1) + '\n')
    print(f'PASS {COUNT} definitions, {len(icons)} icons, {sum(1 for r in data["definitions"] if r["handler"])} handlers')


if __name__ == '__main__':
    main()
