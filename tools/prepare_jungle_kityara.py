#!/usr/bin/env python3
"""Pin the Huline Kityara follow-up (controls 0/83, props 64-67) as a source contract and stage its original media.

Source facts (L4_HJ, WPN room; read-only):
- First meeting: WPN room initialization (callback1 0x47C..0x687) ends with set_local Met_Kityara(local35)=1 on every
  path, so entering Kityara's shop earns it (weapon_shop_state.enter_room applies it).
- Admission p151: local21 Has_Kityara_been_triggered==0, local35==1, shared14 GV_RUNES_TRANSLATED==1, shared25
  GV_KITYARA_DEAD==0. Two locations: control0 (regions 1257/1315/1324, timer prop65, dropped knife prop64) and
  control83 (regions 870/876/892/899/900/914/915, prop66/prop67). Both play E066E.VQA.
- Knife: segment1 end (control ev6/0, owner state0) raises prop65/66 event20 -> local41 kityara_gave_knife=1, prop
  state1 and a player grant of identity 3959297008 (GLOBAL definition29 "30-Empty hand", handler0). The same grant
  follows the prop65/66 kind2 timer and the prop64/67 use after Kityara leaves; prop state makes it one-time.
- Offers ev4/3 (first eligible), hit ev9 and ev5/2/20 (death path) and the leave groups are pinned as well.
Usage: prepare_jungle_kityara.py --game G --geometry GEO --texture TEX --assemblies ASM --output SOURCE_JSON
       [--media-output FRESH_DIR] [--icon-output PNG]
"""
import argparse, hashlib, json, struct
from pathlib import Path
from build_game_atlas import parse_mix, section, u32
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from prepare_jungle_bacatta import predicate
from lol2.map_video_inventory import lookup_movie
from prepare_jungle_bacatta_media import segments
from lol2_material_format import sections as material_sections

CONTROLS = {0: dict(regions=[1257, 1315, 1324], timer=65, drop=64), 83: dict(regions=[870, 876, 892, 899, 900, 914, 915], timer=66, drop=67)}
PROPS = [64, 65, 66, 67]
MOVIE = ('E066E.VQA', '0e9bb9e85c43fc8f')
ITEM = dict(identity=3959297008, definition=29, name='30-Empty hand', catalog_id='jungle:kityara:Empty_hand')
LOCAL_NAMES = {21: 'Has_Kityara_been_triggered', 23: 'Kityara_Given_Orb', 35: 'Met_Kityara', 41: 'kityara_gave_knife', 54: 'Luther_has_firestorm'}
SHARED = [0, 14, 20, 25, 47]

def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ['game', 'geometry', 'texture', 'assemblies', 'output']: p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--media-output', type=Path); p.add_argument('--icon-output', type=Path)
    a = p.parse_args(); root = Path(__file__).resolve().parents[1]
    area = next(x for x in json.loads((root / 'docs/game-source-inventory.json').read_text())['areas'] if x['id'] == 'L4_HJ')
    arc = (a.game / area['source']['file']).read_bytes(); assert hashlib.sha256(arc).hexdigest() == area['source']['sha256']
    entry = next(e for e in parse_mix(arc) if e['key'] == area['source']['geometry_key'])
    raw = arc[entry['offset']:entry['offset'] + entry['size']]; assert hashlib.sha256(raw).hexdigest() == area['source']['geometry_sha256']
    owners, _ = collect_owners(raw, entry['offset'], area['counts']['regions']); _, _, table = section(raw, 0xbc, 0xb8, 5)
    streams = []
    for of, sf in [(0x3c, 0x84), (0x44, 0x8c)]:
        start, _, blob = section(raw, of, sf, 1)
        streams.append({g: [b.hex() for _, b in cmds] for g, cmds in groups(blob)})
    def names_ours(c):
        b = bytes.fromhex(c)
        if len(b) < 4: return False
        target = int.from_bytes(b[2:4], 'little')
        return (b[1] == 0x10 and target in CONTROLS) or (b[1] == 3 and target in PROPS)
    starters = {r for c in CONTROLS.values() for r in c['regions']}
    records = []
    for o in owners:
        cmds = streams[o['stream']][o['group']]
        own = (o['owner_kind'] == 'control' and o['owner'] in CONTROLS) or (o['owner_kind'] == 'prop' and o['owner'] in PROPS)
        if own or any(names_ours(c) for c in cmds):
            n = arc[o['archive_offset']]
            records.append(dict(owner_kind=o['owner_kind'], owner=o['owner'], kind=o['event'], value=o['value'], stream=o['stream'], group=o['group'],
                                predicate=o['predicate'], raw=arc[o['archive_offset']:o['archive_offset'] + n].hex(), commands=cmds))
    # Completeness: every region that names our objects is a known starter; every starter is present.
    # Region groups either start the conversation (op14 op3 on the timer prop, local21=1) or toggle the control's
    # presence (op9 property3 link under p151 as Luther approaches; unconditional property2 unlink elsewhere).
    seen_regions = {r['owner'] for r in records if r['owner_kind'] == 'region'}
    start_found = {r['owner'] for r in records if r['owner_kind'] == 'region' and any(c in ('0e03410003000000', '0e03420003000000') for c in r['commands'])}
    assert start_found == starters, sorted(start_found ^ starters)
    for r in records:
        if r['owner_kind'] == 'region' and r['owner'] not in starters:
            ours = [c for c in r['commands'] if names_ours(c)]
            assert all(c[:2] == '09' and c[8:10] in ('02', '03', '09', '0a') for c in ours), (r['group'], ours)
    # The start groups and knife groups, byte for byte.
    def cmds(kind, owner, event, value, pred=None):
        rows = [r for r in records if (r['owner_kind'], r['owner'], r['kind'], r['value']) == (kind, owner, event, value) and (pred is None or r['predicate'] == pred)]
        assert len(rows) == 1, (kind, owner, event, value, len(rows)); return rows[0]['commands']
    assert cmds('region', 1257, 2, 0)[:1] == ['0e03410003000000'] and 'c60000001501' in cmds('region', 1257, 2, 0)
    assert cmds('region', 870, 2, 0)[:1] == ['0e03420003000000'] and 'c60000001501' in cmds('region', 870, 2, 0)
    assert cmds('prop', 65, 6, 20) == ['c60000002901', '0e03410004000000', '100341000100', '03010000f013feeb04000000']
    assert cmds('prop', 66, 6, 20) == ['c60000002901', '0e03420004000000', '100342000100', '03010000f013feeb04000000']
    assert cmds('control', 0, 6, 0, 206)[0] == '090341001500' and cmds('control', 83, 6, 0, 206)[0] == '090342001500'
    predicates = {}
    def add(pn):
        if pn is None or str(pn) in predicates: return
        e = predicate(table, pn); predicates[str(pn)] = e
        for side in (e['left'], e['right']):
            if 'predicate' in side: add(side['predicate'])
    for r in records: add(r['predicate'])
    assert json.dumps(predicates['151']).count('"local": 21') == 1 and json.dumps(predicates['151']).count('"local": 35') == 1
    # Placements, regions, timers, offers.
    _, _, props = section(raw, 0x14, 0x60, 37); _, _, controls = section(raw, 0x18, 0x64, 33)
    def placement(blob, n, size):
        row = blob[n * size:(n + 1) * size]; x, z, h, y = struct.unpack_from('<hhHh', row)
        return dict(id=n, position=[x, y, -z], heading=h, flags=struct.unpack_from('<H', row, 8)[0], raw=row.hex())
    asm = {t['index']: t for t in json.loads(a.assemblies.read_text())['source_templates']}
    tex = a.texture.read_bytes(); sec = material_sections(tex)
    locations = {}
    for c, spec in CONTROLS.items():
        ctl = placement(controls, c, 33); template = bytes.fromhex(ctl['raw'])[32]
        tpl = bytes.fromhex(asm[template]['raw_hex']); resource = struct.unpack_from('<H', tpl, 36)[0]
        d = struct.unpack_from('<6H11I', tex, sec[2] + resource * 56); payload = tex[sec[3] + d[7]:sec[3] + d[7] + d[12]]
        assert d[3] == 0x143 and payload[8:].rstrip(b'\0').upper() == MOVIE[0].encode()
        ctl.update(template=template, dimensions=asm[template]['dimensions'], movie_resource=resource)
        locations[str(c)] = dict(control=ctl, timer_prop=spec['timer'], drop_prop=spec['drop'], regions=spec['regions'])
    geo = json.loads(a.geometry.read_text())
    def region(n):
        row = geo['regions'][n]; assert row['id'] == n
        return dict(id=n, polygon=[[geo['vertices_fixed'][v][0] / 65536, -geo['vertices_fixed'][v][1] / 65536] for v in row['vertex_indices']],
                    floor_min=min(row['floor_corners']), floor_max=max(row['floor_corners']))
    timers = {}
    for pr in (65, 66):
        rows = [r for r in records if r['owner_kind'] == 'prop' and r['owner'] == pr and r['kind'] == 2]
        timers[str(pr)] = []
        for i, r in enumerate(rows):
            b = bytes.fromhex(r['raw']); timers[str(pr)].append(dict(ordinal=i, group=r['group'], value=r['value'], flags=b[5], range=[b[7], b[6]], remaining=struct.unpack_from('<H', b, 8)[0]))
    offers = [dict(owner=r['owner'], group=r['group'], predicate=r['predicate'], mode=bytes.fromhex(r['raw'])[4], identity=u32(bytes.fromhex(r['raw']), 6) if len(r['raw']) >= 20 else 0, raw=r['raw'])
              for r in records if r['owner_kind'] == 'control' and r['kind'] == 4]
    # Names.
    count, at = u32(raw, 0xb0), u32(raw, 0xb4)
    for n, expect in LOCAL_NAMES.items(): assert raw[at + count + n * 41:at + count + n * 41 + 41].split(b'\0')[0].decode() == expect
    ga = (a.game / 'GLOBAL.MIX').read_bytes(); ge = next(e for e in parse_mix(ga) if e['key'] == 3984507021); gblob = ga[ge['offset']:ge['offset'] + ge['size']]
    assert hashlib.sha256(gblob).hexdigest() == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    shared_names = {}
    for n in SHARED:
        off = u32(gblob, 0x64) + u32(gblob, 0x60) + n * 41; shared_names[str(n)] = gblob[off:off + 41].split(b'\0')[0].decode()
    assert shared_names['14'] == 'GV_RUNES_TRANSLATED' and shared_names['25'] == 'GV_KITYARA_DEAD' and shared_names['47'] == 'GV_LUTHER_KNOWS_ABOUT_DANIEL'
    base, dcount = u32(gblob, 4), u32(gblob, 0x34); dnames = base + dcount * 91 + 4; dnames += u32(gblob, dnames - 4) * 16 + 4; dnames += u32(gblob, dnames - 4) * 12
    record = gblob[base + 29 * 91:base + 30 * 91]
    assert u32(record, 24) == ITEM['identity'] and gblob[dnames + 29 * 30:dnames + 29 * 30 + 24].split(b'\0')[0].decode() == ITEM['name'] and record[0x42] == 0
    movie = lookup_movie(a.game, 'L4_HJ', MOVIE[0]); assert movie['status'] == 'exact' and movie['sha256'].startswith(MOVIE[1])
    result = dict(version=1, source=area['source'], locations=locations, props={str(n): placement(props, n, 37) for n in PROPS},
                  regions=[region(n) for n in sorted(seen_regions)], start_regions=sorted(starters), records=records, predicates=predicates, timers=timers, offers=offers,
                  local_names={str(k): v for k, v in LOCAL_NAMES.items()}, owned_locals=[21], shop_bank_locals=[23, 35, 41, 54], shared_names=shared_names,
                  item=dict(ITEM, record=record.hex()), movie=dict(name=MOVIE[0], sha256=movie['sha256'], fps=15, segments=segments(movie['blob'], 15)),
                  first_meeting='WPN room initialization callback1 sets Met_Kityara=1 on every path (WPN_.WOM 0x672..0x67F)',
                  scope='Direct source events. Region entry edge, visibility, body/aim, presentation and timer clocks are modern adapters in the live owner.')
    a.output.parent.mkdir(parents=True, exist_ok=True); a.output.write_text(json.dumps(result, indent=1) + '\n')
    if a.icon_output:
        icon(a, root)
    if a.media_output:
        media(a, movie)
    print(f"PASS kityara contract: {len(records)} records, {len(starters)} start regions, {len(seen_regions)} regions, segments {len(result['movie']['segments'])}, offers {len(offers)}")

def icon(a, root):
    from PIL import Image
    from prepare_hive_wax import entry, sections, rgb_palette, decode_rows
    definitions = entry('GLOBAL.MIX', 3984507021); base, count = u32(definitions, 4), u32(definitions, 0x34)
    state = base + count * 91 + 4; view = state + u32(definitions, state - 4) * 16 + 4
    state_index = view_index = 0; resource = None
    for index in range(count):
        rec = definitions[base + index * 91:][:91]
        for sel in range(rec[46] + rec[47]):
            views = max(1, struct.unpack_from('<b', definitions, state + state_index * 16 + 13)[0])
            if sel == 0 and index == ITEM['definition']: resource = struct.unpack_from('<h', definitions, view + view_index * 12)[0]
            state_index += 1; view_index += views
    graphics = entry('LOCAL.MIX', 4018716831); sec = sections(graphics); palette = rgb_palette(graphics[u32(graphics, 4):][:768], 6)
    desc = struct.unpack_from('<6H11I', graphics, sec[2] + resource * 56)
    width, height, pixels, _ = decode_rows(graphics[sec[3] + desc[7]:][:desc[12]], allow_special=True)
    rgba = bytes(c for px in pixels for c in (*palette[px * 3:px * 3 + 3], 0 if px in (0, 1) else 255))
    a.icon_output.parent.mkdir(parents=True, exist_ok=True); Image.frombytes('RGBA', (width, height), rgba).save(a.icon_output)
    print('icon resource', resource, (width, height))

def media(a, movie):
    from PIL import Image
    from prepare_jungle_exit_movies import decode, audio, parse_vqa_chunks
    out = a.media_output; assert not out.exists(), 'Use a fresh media directory'
    out.mkdir(parents=True); cache = out / 'cache'; cache.mkdir(); vqa = cache / MOVIE[0]; vqa.write_bytes(movie['blob']); h = movie['vqhd']
    assert (h['count'], h['width'], h['height'], h['fps']) == (1100, 392, 620, 15), h
    frames = decode(vqa, cache / 'decoded', h['count'], (h['width'], h['height'])); rows = []
    key = Image.open(frames[0]).convert('RGB').getpixel((0, 0))
    for i, frame in enumerate(frames):
        im = Image.open(frame).convert('RGBA').transpose(Image.Transpose.ROTATE_270)
        im.putdata([(r, g, b, 0 if (r, g, b) == key else 255) for r, g, b, _ in im.getdata()]); name = f'frame_{i:04d}.png'; im.save(out / name); rows.append(name)
    samples = sum(len(v) * 2 for k, v in parse_vqa_chunks(movie['blob']) if k == b'SND2'); rate = audio(vqa, out / 'voice.wav', samples)
    import shutil; shutil.rmtree(cache)
    manifest = dict(version=1, sha256=movie['sha256'], movie=MOVIE[0], frames=rows, width=h['height'], height=h['width'], fps=15, rotation=270, key=list(key),
                    segments=segments(movie['blob'], 15), audio='voice.wav', samples=samples, rate=rate)
    (out / 'media.json').write_text(json.dumps(manifest, indent=1) + '\n'); print('media', len(rows), 'frames; key', key, 'samples', samples, 'rate', rate)

if __name__ == '__main__':
    main()
