#!/usr/bin/env python3
"""Pin the Huline village Confidante (L4_HJ controls 112/123) as a source contract and stage its original media.

Source facts (read-only; AI_COMMS/grok_act1_mechanics_20261025/VILLAGE_ESCAPE_CONTRACT.md, Grok check 9235c210):
- Control123 (E102E.VQA, template47) is the first meeting: barrel prop1465 sighted (event5, p96: local6==0, prop state0,
  Daniel known or Kityara dead) links it and loops its idle segment3; region3408 (p198: local20==0 ...) sets local20=1,
  holds and places Luther and focuses it; the next idle loop end (event6/1, owner state1) starts timer prop68 and plays
  segment0; its end (event6/0) sets local27 Met_Confidant=1, releases Luther and unlinks it. Region3397 (p170) then
  sets local20=2. Timer prop68 (23 s) also sets local27=1.
- Control112 (E103E.VQA, template52) is the second meeting: prop492 sighted (p105: local6 or local33 Anyar_Attacked,
  prop state0, Met_Confidant) links it (prop492 state1) and loops segment3; region3408 (p175: local20==2 ..., local39==0)
  holds/places Luther; the loop end (state1) sets state2 and plays segment0; its end (state2) adds 1 Soul, releases and
  unlinks it.
- Kill (event9 value0, wildcard masks, threshold1, mode1, one-shot 0x80; groups 25628/25802): local39 Killed_Confidante=1,
  Soul-1, release, local20=3 (112) or 2 (123), death segment1 once, state5; 123 also sets prop492 state5 and sound269.
  The state5 end (p9) unlinks it with sound227.
- Not hosted here: gate leaves 78/79 (groups 28068/28140, p196 local39==1 AND shared29==1) need a hit context with
  bit 0x0800 that no traced producer supplies; barrel prop1465's own hit group (p37 Barrel_Variable) and control100's
  CHUT stop group 21322 belong to other owners. They are recorded under `not_hosted`.
Usage: prepare_jungle_confidante.py --game G --geometry GEO --output SOURCE_JSON [--media-root FRESH_DIR]
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'tools/lol2'))

CONTROLS = {112: dict(template=52, resource=510, movie='E103E.VQA', sha='c2bbfa9bfca14f7ae25e46ccc28d9d096a98bfa2039c7f7f0790d25f7a9f5935', starter=492),
            123: dict(template=47, resource=511, movie='E102E.VQA', sha='892664913976b06709365a8c179add1f4013c7611a1f73ba99139c8f31473f10', starter=1465)}
PROPS = [68, 492, 1465]
REGIONS = [3247, 3253, 3397, 3408, 4523]
LOCAL_NAMES = {6: 'Has_Luther_smoked_the_Cheifs_hut', 20: 'Confidante_trigger_is_active', 27: 'Met_Confidant', 33: 'Anyar_Attacked', 39: 'Killed_Confidante'}
OWNED_LOCALS = [20, 27, 39]
KELSRICK_LOCALS = [6, 33]
SHARED = [0, 25, 29, 47]
SOUNDS = [227, 269]
# Exact command bytes from the verified contract (archive offsets 12753938 and 12754112).
KILL = {25628: ['021070000600', 'c60000002701', 'ce00000000ff', '020100002700', 'c60000001403', '0810700007000000', '081070000a000100', '101070000500'],
        25802: ['02107b000600', 'c60000002701', '1003ec010500', 'ce00000000ff', '14107b000d0150810a14', '020100002700', 'c60000001402', '08107b0007000000', '08107b000a000100', '10107b000500']}
LEAVES = {78: 28068, 79: 28140}


def main():
    from verify_actor_item_grants import source_area
    from build_game_atlas import section
    from prepare_jungle_bacatta import predicate
    from prepare_jungle_bacatta_media import segments
    from lol2_source_format import parse_mix, u32
    from lol2_material_format import sections
    from lol2.map_video_inventory import lookup_movie
    import map_materials as mm
    import export_map_movables as em
    p = argparse.ArgumentParser(description=__doc__)
    for name in ['game', 'geometry', 'output']: p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--media-root', type=Path)
    a = p.parse_args()
    area, arc, item, raw, owners, streams = source_area('L4_HJ', a.game)
    _, _, table = section(raw, 0xbc, 0xb8, 5)

    def cmds(o): return [c['raw_hex'] for c in streams[o['stream']][o['group']]]
    def rec(o): return arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]].hex()
    def names_control(c):
        b = bytes.fromhex(c); return len(b) >= 4 and b[1] == 0x10 and int.from_bytes(b[2:4], 'little') in CONTROLS
    hosted, not_hosted = [], []
    for o in owners:
        row = dict(owner_kind=o['owner_kind'], owner=o['owner'], kind=o['event'], value=o['value'], stream=o['stream'], group=o['group'],
                   predicate=o['predicate'], archive_offset=o['archive_offset'], raw=rec(o), commands=cmds(o))
        own = (o['owner_kind'] == 'control' and o['owner'] in CONTROLS) or (o['owner_kind'] == 'region' and o['owner'] in REGIONS) \
            or (o['owner_kind'] == 'prop' and o['owner'] == 68 and o['event'] == 2) or (o['owner_kind'] == 'prop' and o['owner'] in (492, 1465) and o['event'] == 5)
        if own: hosted.append(row)
        elif any(names_control(c) for c in row['commands']) or (o['owner_kind'] == 'prop' and o['owner'] == 1465) \
                or (o['owner_kind'] == 'movable' and o['owner'] in LEAVES and o['event'] == 9):
            not_hosted.append(row)
    key = lambda r: (r['owner_kind'], r['owner'], r['kind'], r['value'], r['group'])
    hosted.sort(key=key); not_hosted.sort(key=key)
    # Every hosted region group either names a Confidante control or is region3397's local20 step.
    for r in hosted:
        if r['owner_kind'] == 'region':
            assert any(names_control(c) for c in r['commands']) or r['commands'] == ['c60000001402'], r
    assert sorted((r['owner'], r['group']) for r in hosted if r['owner_kind'] == 'region') == [(3247, 6340), (3253, 6360), (3397, 6840), (3408, 6852), (3408, 6906), (4523, 19340)]
    by_group = {r['group']: r for r in hosted}
    for g, expect in KILL.items():
        r = by_group[g]; assert r['commands'] == expect and r['kind'] == 9 and r['predicate'] is None, (g, r)
        b = bytes.fromhex(r['raw'])
        # kind9 layout: mask0 +4, mask1 +6, threshold +8, mode +9 (&7; 0x80 one-shot) (AE2C8/AE433).
        assert struct.unpack_from('<HH', b, 4) == (0, 0) and b[8] == 1 and b[9] == 0x81, b.hex()
    assert by_group[25802]['archive_offset'] == 12768740 and by_group[25628]['archive_offset'] == 12768698
    hits = {str(r['owner']): dict(group=r['group'], mask0=0, mask1=0, threshold=1, mode=1, one_shot=True, raw=r['raw']) for r in hosted if r['kind'] == 9}
    leaves = {}
    for r in not_hosted:
        if r['owner_kind'] == 'movable':
            b = bytes.fromhex(r['raw']); assert r['group'] == LEAVES[r['owner']] and r['predicate'] == 196
            leaves[str(r['owner'])] = dict(group=r['group'], mask0=struct.unpack_from('<H', b, 4)[0], mask1=struct.unpack_from('<H', b, 6)[0], threshold=b[8], mode=b[9] & 7, raw=r['raw'], commands=r['commands'])
            assert leaves[str(r['owner'])]['mask0'] == 0x0800 and leaves[str(r['owner'])]['mode'] == 4
    assert sorted(leaves) == ['78', '79']
    predicates = {}
    def add(n):
        if n is None or str(n) in predicates: return
        e = predicate(table, n); predicates[str(n)] = e
        for side in (e['left'], e['right']):
            if 'predicate' in side: add(side['predicate'])
    for r in hosted + not_hosted: add(r['predicate'])
    s = json.dumps
    assert '"local": 39' in s(predicates['175']) and '"local": 27' in s(predicates['105']) and '"shared": 29' in s(predicates['196'])
    # Placements (bit 0x1000 of the flags word at +8 marks an object absent at load).
    _, _, props = section(raw, 0x14, 0x60, 37); _, _, controls = section(raw, 0x18, 0x64, 33)
    def placement(blob, n, size):
        row = blob[n * size:(n + 1) * size]; x, z, h, y = struct.unpack_from('<hhHh', row)
        return dict(id=n, position=[x, y, -z], heading=h, flags=struct.unpack_from('<H', row, 8)[0], raw=row.hex())
    mix = arc; entries = mm.parse_mix(mix); ident = mm.identify_entries(mix, entries, area['source']['geometry_key'])
    meta = mix[ident['metadata_entry']['offset']:ident['metadata_entry']['offset'] + ident['metadata_entry']['size']]
    em.require = lambda ok, msg: None if ok else (_ for _ in ()).throw(AssertionError(msg))
    templates = em.load_movable_templates(meta)['templates']
    tex, _ = mm.decode_lzo_container(mix, ident['texture_entry']); sec = sections(tex)
    locations = {}
    for c, spec in CONTROLS.items():
        ctl = placement(controls, c, 33); template = bytes.fromhex(ctl['raw'])[32]; assert template == spec['template']
        tpl = bytes.fromhex(templates[template]['raw_hex']); resource = struct.unpack_from('<H', tpl, 36)[0]; assert resource == spec['resource']
        d = struct.unpack_from('<6H11I', tex, sec[2] + resource * 56); payload = tex[sec[3] + d[7]:sec[3] + d[7] + d[12]]
        assert d[3] == 0x143 and payload[8:].rstrip(b'\0').upper() == spec['movie'].encode()
        movie = lookup_movie(a.game, 'L4_HJ', spec['movie']); assert movie['status'] == 'exact' and movie['sha256'] == spec['sha']
        assert (ctl['flags'] & 0x1000) != 0
        ctl.update(template=template, dimensions=templates[template]['dimensions'], movie_resource=resource)
        locations[str(c)] = dict(control=ctl, starter_prop=spec['starter'], movie=dict(name=spec['movie'], sha256=movie['sha256'], fps=15, segments=segments(movie['blob'], 15)))
        assert [x['name'][:5] for x in locations[str(c)]['movie']['segments']] == ['HOthr', 'HDdie', 'HDead', 'HLoit']
    assert locations['112']['control']['position'] == [-1281, 24, -4225] and locations['123']['control']['position'] == [-1283, 24, -4228]
    timers = {}
    for r in hosted:
        if r['owner_kind'] == 'prop' and r['kind'] == 2:
            b = bytes.fromhex(r['raw'])
            timers.setdefault(str(r['owner']), []).append(dict(ordinal=len(timers.get(str(r['owner']), [])), group=r['group'], value=r['value'], flags=b[5], range=[b[7], b[6]], remaining=struct.unpack_from('<H', b, 8)[0]))
    assert timers == {'68': [dict(ordinal=0, group=260, value=304, flags=1, range=[0, 23], remaining=1380)]}
    geo_bytes = a.geometry.read_bytes(); geo = json.loads(geo_bytes)
    def region(n):
        row = geo['regions'][n]; assert row['id'] == n
        return dict(id=n, polygon=[[geo['vertices_fixed'][v][0] / 65536, -geo['vertices_fixed'][v][1] / 65536] for v in row['vertex_indices']],
                    floor_min=min(row['floor_corners']), floor_max=max(row['floor_corners']))
    count, at = u32(raw, 0xb0), u32(raw, 0xb4)
    for n, expect in LOCAL_NAMES.items():
        assert raw[at + count + n * 41:at + count + n * 41 + 41].split(b'\0')[0].decode() == expect and raw[at + n] == 0
    ga = (a.game / 'GLOBAL.MIX').read_bytes(); ge = next(e for e in parse_mix(ga) if e['key'] == 3984507021); gblob = ga[ge['offset']:ge['offset'] + ge['size']]
    assert hashlib.sha256(gblob).hexdigest() == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    shared_names = {str(n): gblob[u32(gblob, 0x64) + u32(gblob, 0x60) + n * 41:u32(gblob, 0x64) + u32(gblob, 0x60) + n * 41 + 41].split(b'\0')[0].decode() for n in SHARED}
    assert shared_names == {'0': 'GV_LUTHERS_SOUL', '25': 'GV_KITYARA_DEAD', '29': 'GV_HULINE_ALERT', '47': 'GV_LUTHER_KNOWS_ABOUT_DANIEL'}, shared_names
    from prepare_creature_audio_clips import sound_bank, stage_clips
    bank = sound_bank(a.game); rcount, rtable = struct.unpack_from('<II', bank, 0x258)
    sound_names = {n: bank[rtable + n * 60 + 16:rtable + (n + 1) * 60].split(b'\0')[0].decode() for n in SOUNDS}
    result = dict(version=1, source=area['source'], geometry_sha256=hashlib.sha256(geo_bytes).hexdigest(), locations=locations,
                  props={str(n): placement(props, n, 37) for n in PROPS}, regions=[region(n) for n in REGIONS], records=hosted,
                  predicates=predicates, timers=timers, hits=hits, local_names={str(k): v for k, v in LOCAL_NAMES.items()},
                  owned_locals=OWNED_LOCALS, kelsrick_locals=KELSRICK_LOCALS, shared_names=shared_names,
                  sounds={str(n): sound_names[n] for n in SOUNDS},
                  not_hosted=dict(records=not_hosted, gate_leaves=leaves,
                                  reason='Leaf groups need a hit context carrying bit 0x0800 (AE2C8 mask test) with context+0x26 <= threshold (mode4); '
                                         'no traced producer supplies it (Grok contract, item 4). Barrel prop1465 and control100 belong to other owners.'),
                  scope='Direct source events. Sight edges, region entry edges, body/aim reach, the idle presentation and clip clocks are modern adapters in the live owner.')
    a.output.parent.mkdir(parents=True, exist_ok=True); a.output.write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS confidante contract: {len(hosted)} hosted groups, {len(not_hosted)} recorded not hosted, predicates {sorted(predicates, key=int)}')
    if a.media_root:
        stage(a, locations, sound_names)


def stage(a, locations, sound_names):
    from PIL import Image
    from lol2.map_video_inventory import lookup_movie
    from prepare_jungle_exit_movies import decode, audio, parse_vqa_chunks
    from prepare_creature_audio_clips import stage_clips
    import shutil
    assert not a.media_root.exists(), 'Use a fresh media root'
    base = a.media_root / 'assets/lol2/generated/jungle_confidante_media'
    for c, loc in locations.items():
        movie = lookup_movie(a.game, 'L4_HJ', loc['movie']['name']); assert movie['sha256'] == loc['movie']['sha256']
        out = base / c; out.mkdir(parents=True); cache = a.media_root / 'cache' / c; cache.mkdir(parents=True)
        vqa = cache / loc['movie']['name']; vqa.write_bytes(movie['blob']); h = movie['vqhd']
        frames = decode(vqa, cache / 'decoded', h['count'], (h['width'], h['height'])); rows = []
        key = Image.open(frames[0]).convert('RGB').getpixel((0, 0))
        for i, frame in enumerate(frames):
            im = Image.open(frame).convert('RGBA').transpose(Image.Transpose.ROTATE_270)
            im.putdata([(r, g, b, 0 if (r, g, b) == key else 255) for r, g, b, _ in im.getdata()]); name = f'frame_{i:04d}.png'; im.save(out / name); rows.append(name)
        samples = sum(len(v) * 2 for k, v in parse_vqa_chunks(movie['blob']) if k == b'SND2'); rate = audio(vqa, out / 'voice.wav', samples)
        manifest = dict(version=1, sha256=movie['sha256'], movie=loc['movie']['name'], frames=rows, width=h['height'], height=h['width'], fps=15, rotation=270,
                        key=list(key), segments=loc['movie']['segments'], audio='voice.wav', samples=samples, rate=rate)
        (out / 'media.json').write_text(json.dumps(manifest, indent=1) + '\n'); print('media', c, len(rows), 'frames; key', key, 'samples', samples, 'rate', rate)
    shutil.rmtree(a.media_root / 'cache')
    stage_clips(a.media_root, 'jungle_confidante_media/sounds', SOUNDS, sound_names, game=a.game)
    print('sounds', sound_names)


if __name__ == '__main__':
    main()
