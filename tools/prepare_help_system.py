#!/usr/bin/env python3
"""Stage the original in-game help texts and the help-page art used by scripts/lol2/help_system.gd.

Native help (LOLG.DAT):
  op2 player subs 0x29/0x2A/0x2B/0x2C/0x2D/0x2E/0x32/0x33 (handlers D86B6, D828A, D82CD, D8310, D8659, D8352, D8607,
  D8395) need player+0x22A bit0 (help enabled), test-and-set one bit at player+0x20C (topic t = 1..8,
  bit 1 << (t-1)) and call 73FF0(t), which stores the topic, loads helptext.trr / help.pcx (70BF8(2)) and runs the
  help UI 15BB18 (layout not decoded). Subs 0x2F, 0x30 and 0x31 are NOT help (other handlers).
helptext.trr = LOCALLNG.MIX entry 3: u32 count n, n u32 ids, n+1 u32 offsets; string i is the NUL-terminated text at
offset[i] + 4. Topic t: banner id 0x27 + t ("Press for help on ..."), page id [0,1,2,3,4,5,8,9][t-1]; ids 7 + 6 =
"Press " + key + " to leave or enter the help system."; 0x13.. = per-area Draracle hint pages (not hosted).
help.pcx is referenced by the executable but is not in the GOG data files (no MIX entry, no loose file), and the
longplay's red-eye banner icon is not found in any shipped shape/WSA. Adapters (docs/DEVIATIONS.md): the page uses
LOCAL.MIX PRCHUNRL.PCX (the original unrolled-parchment scroll, blue key colour made transparent) and the icon uses
GLOBAL.MIX intrface.shp shape 119 (red jewel in gold).
Usage: prepare_help_system.py --game GAME [--project PROJECT]
"""
import argparse, hashlib, io, json, struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix
from lol2_movie_format import ww_hash_v1
from prepare_museum_interface import shape

ROOT = Path(__file__).resolve().parents[1]
TOPICS = {1: 'inventory', 2: 'automapper', 3: 'magic', 4: 'combat', 5: 'movement', 6: 'miscellaneous', 7: 'looking', 8: 'targeting'}
SUBS = {0x29: 1, 0x2A: 2, 0x2B: 3, 0x2C: 4, 0x2D: 5, 0x2E: 6, 0x32: 7, 0x33: 8}
PAGES = [0, 1, 2, 3, 4, 5, 8, 9]


def sha(raw): return hashlib.sha256(raw).hexdigest()


def strings(trr: bytes) -> dict:
    n = struct.unpack_from('<I', trr, 0)[0]
    ids = struct.unpack_from('<%dI' % n, trr, 4)
    offsets = struct.unpack_from('<%dI' % (n + 1), trr, 4 + 4 * n)
    assert offsets[0] + 4 == 4 + 4 * n + 4 * (n + 1), 'helptext.trr header'
    out = {}
    for i in range(n):
        raw = trr[offsets[i] + 4:offsets[i + 1] + 4]
        out[ids[i]] = raw.split(b'\0')[0].decode('latin-1')
    return out


# L1_DC records that run a help sub (owner kind, index, event, value, group, sub). Asserted byte for byte.
CAVE_RECORDS = [('control', 75, 4, 0x29), ('prop', 144, 4, 0x29), ('prop', 145, 4, 0x29), ('prop', 146, 4, 0x29),
                ('prop', 147, 4, 0x29), ('prop', 148, 4, 0x29), ('prop', 149, 4, 0x29), ('prop', 641, 4, 0x29),
                ('actor', 56, 3, 0x29), ('prop', 927, 5, 0x2A), ('actor', 56, 5, 0x2B), ('prop', 422, 2, 0x2C),
                ('prop', 1219, 5, 0x2E), ('region', 1077, 4, 0x32), ('prop', 1363, 5, 0x33)]
SIGHTED_PROPS = {927: 2, 1219: 6, 1363: 8}
MAP = Path('~/lol2_out/all_maps_20260922/L1_DC')


def cave_triggers(game: Path) -> dict:
    from verify_actor_item_grants import source_area
    area, arc, item, raw, owners, streams = source_area('L1_DC', game)
    records = []
    for kind, index, event, sub in CAVE_RECORDS:
        rows = [o for o in owners if o['owner_kind'] == kind and o['owner'] == index and o['event'] == event]
        hit = [o for o in rows if any(c['raw_hex'] == '02010000%02x00' % sub for c in streams[o['stream']][o['group']])]
        assert len(hit) == 1, (kind, index, event, sub, rows)
        o = hit[0]
        records.append(dict(owner=kind, index=index, event=event, value=o['value'], group=o['group'], predicate=o['predicate'],
                            sub=sub, topic=SUBS[sub], commands=[c['raw_hex'] for c in streams[o['stream']][o['group']]]))
    unowned = sorted(g for s, st in enumerate(streams) for g, cmds in st.items()
                     if not any(o['stream'] == s and o['group'] == g for o in owners) and any(c['raw_hex'] == '0201000029' + '00' for c in cmds))
    props = {q['record']: q for q in json.loads((MAP / 'props/props.json').read_text())['props']}
    sighted = {str(r): dict(topic=t, position=props[r]['position'], height=props[r]['height'], template=props[r]['template'])
               for r, t in SIGHTED_PROPS.items()}
    nav = json.loads((ROOT / 'assets/lol2/generated/creature_nav/L1_DC.json').read_text())['regions']
    region = dict(region=1077, topic=7, polygon=nav[1077][0], floor_min=nav[1077][1], floor_max=nav[1077][2])
    return dict(version=1, area='L1_DC', archive_sha256=sha(arc), records=records, unowned_inventory_groups=unowned,
                sighted=sighted, region=region, captain=dict(actor='56', loot_topic=1, sighted_topic=3),
                sight_distance=1600, not_hosted=['prop422 kind2 timer (topic 4 combat): its kind6 value265 starter is not traced',
                                                 'topic 5 movement: no Act 1 trigger in L1_DC/L3_DH/L4_HJ/L5_HC'])


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    lng = (a.game / 'LOCALLNG.MIX').read_bytes()
    entry = parse_mix(lng)[3]
    assert entry['key'] == ww_hash_v1('HELPTEXT.TRR'), 'LOCALLNG entry 3 is not helptext.trr'
    trr = lng[entry['offset']:entry['offset'] + entry['size']]
    texts = strings(trr)
    for t in TOPICS:
        assert texts[0x27 + t].startswith('Press for'), (t, texts[0x27 + t])
        assert texts[PAGES[t - 1]].startswith('^'), (t, texts[PAGES[t - 1]][:20])
    assert texts[0].startswith('^Inventory') and texts[9].startswith('^Targeting') and texts[7] == 'Press '
    local = (a.game / 'LOCAL.MIX').read_bytes()
    le = {e['key']: e for e in parse_mix(local)}
    blob = lambda arc, e: arc[e['offset']:e['offset'] + e['size']]
    scroll_raw = blob(local, le[ww_hash_v1('PRCHUNRL.PCX')])
    scroll = Image.open(io.BytesIO(scroll_raw))
    assert scroll.size == (320, 200) and scroll.mode == 'P'
    key = scroll.getpixel((0, 0))  # blue surround = key colour
    rgba = scroll.convert('RGBA')
    px = rgba.load(); src = scroll.load()
    for y in range(scroll.size[1]):
        for x in range(scroll.size[0]):
            if src[x, y] == key: px[x, y] = (0, 0, 0, 0)
    glob_mix = (a.game / 'GLOBAL.MIX').read_bytes()
    ge = {e['key']: e for e in parse_mix(glob_mix)}
    shp = blob(glob_mix, ge[606080735])
    pal = blob(local, le[1915865337])[:768]
    palette = bytes(round(v * 255 / 63) for v in pal)
    w, h, pixels = shape(shp, 119)
    icon = Image.frombytes('P', (w, h), bytes(pixels)); icon.putpalette(palette)
    icon_rgba = icon.convert('RGBA'); ip = icon_rgba.load()
    for y in range(h):
        for x in range(w):
            if pixels[y * w + x] == 0: ip[x, y] = (0, 0, 0, 0)
    out = a.project / 'assets/lol2/generated/help_system'
    out.mkdir(parents=True, exist_ok=True)
    rgba.save(out / 'page.png'); icon_rgba.save(out / 'icon.png')
    data = dict(version=1, topics={str(t): dict(name=TOPICS[t], banner=texts[0x27 + t], page=texts[PAGES[t - 1]]) for t in TOPICS},
                subs={hex(s): t for s, t in SUBS.items()}, leave=[texts[7], texts[6]],
                hints={hex(i): texts[i] for i in range(0x13, 0x28) if i in texts},
                source=dict(helptext_sha256=sha(trr), prchunrl_sha256=sha(scroll_raw), intrface_sha256=sha(shp), icon_shape=119))
    (out / 'texts.json').write_text(json.dumps(data, indent=1, ensure_ascii=False) + '\n')
    triggers = cave_triggers(a.game)
    (a.project / 'scripts/lol2/cave_help_source.json').write_text(json.dumps(triggers, indent=1) + '\n')
    print('PASS help system: 8 topics, page/icon staged', out, '; cave triggers', len(triggers['records']))


if __name__ == '__main__':
    main()
