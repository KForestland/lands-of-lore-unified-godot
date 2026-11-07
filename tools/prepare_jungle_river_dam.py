#!/usr/bin/env python3
"""Stage the Huline Jungle river rock / dam (L4_HJ prop250; longplay 35:36-36:42) for scripts/lol2/jungle_river_dam.gd.

Source (verify_actor_item_grants.source_area L4_HJ; every pin below is asserted):
  prop250 (template113 rock, placement durability byte30 = 50) kind9 records, value 0x0906 (melee masks; the Spark
  context 1/1 does not match), predicate206 (owner state 0):
    g3154 (threshold 1, mode4: remaining durability <= 1): op197 region4543 sub5 (clear its impassable bits), op9
      prop71 property21 (raise event20: g280 sets property19 = 20 on 37 river stones), 2 x op2 sub0x0B arg5
      (fighting experience 500 each), op14 prop2706 sub3 (start its timer), op9 prop250 property8, shake, op20
      sound 719, op9 property2 (unlink) on the 10 foam props 2233-2242, op16 prop250 state1, op5 prop250 selector2
      (stump), and 76 op196 floor movers: region4543 absolute -70, 66 channel regions by -50 and 9 by -20 (relative,
      byte6 bit3), all speed 3.
    g4206 (threshold 1, mode1, every admitted hit): shake + op20 sound 956.
  Each of the 75 relative regions has a region kind11 event5 (floor movement end) record whose group runs op204 on
  that same region, preset 2 (water material 808 -> mud).
  prop2706 (template30 tree) kind2 timer, value word 0x0110, byte5 bit0 set (stopped), byte6/7 range 30/15, stored
  countdown 1140 ticks; its group g16764 runs player op2 sub0x15 arg 0x48 (timed form; native 649D8 decodes arg
  0x48 to random(120..180): low nibble*15 .. +high nibble*15) and op14 sub4 (stop).
  Burrow: region4543 opens into 26 regions (floor -70, ceiling -50) holding world items 41/42 (57a-Fire crstl),
  68 (65a-Storm), 69-71 (66-Ancients stn), 72 (136-SS3).
Geometry: the Jungle scene is regenerated twice with tools/prepare_jungle_review.py from the same inputs, once as
published and once with the movers and mud presets applied (the drained river). The first must equal --jungle-review;
the wall faces that differ are handed to the runtime host (initial set before the break, drained set after).
Output: PROJECT/assets/lol2/generated/jungle_river_dam/{source.json, PNGs}.
Usage: prepare_jungle_river_dam.py --game-root GAME --geometry GEOMETRY --material-root MATERIALS --jungle-review REVIEW
       [--project PROJECT]
"""
import argparse, copy, hashlib, json, shutil, struct, subprocess, sys, tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
ROCK, TIMER_PROP, STONE_TRIGGER = 250, 2706, 71
FOAM = list(range(2233, 2243))
BURROW_MOUTH = 4543
ITEM_ROWS = [41, 42, 68, 69, 70, 71, 72]
G_BREAK, G_HIT, G_TIMER, G_STONES = 3154, 4206, 16764, 280
RECORDS = {G_BREAK: '0a09520c060904000104', G_HIT: '0a096e10060904000101'}
TIMER_RECORD = '0a027c4110011e0f7404'
TIMER_COMMANDS = ['020100001548', '0e03920a04000000']
HIT_COMMANDS = ['d090000000010100', '1403fa00bc03ff000f06']


def mover(raw):
    b = bytes.fromhex(raw)
    assert b[0] == 0xC4 and b[1] == 0x90 and len(b) == 12, raw
    region, target = struct.unpack_from('<Hh', b, 2)
    assert not b[6] & 1, 'ceiling mover'
    return dict(region=region, target=target, relative=bool(b[6] & 8), speed=b[7])


def scene(game, geometry, materials, out):
    subprocess.run([sys.executable, str(TOOLS / 'prepare_jungle_review.py'), '--game-root', str(game), '--geometry', str(geometry),
                    '--material-root', str(materials), '--output-root', str(out)], check=True, stdout=subprocess.DEVNULL, env={'PYTHONPATH': str(TOOLS), 'PATH': '/usr/bin:/bin'})
    folder = out / 'assets/lol2/generated/jungle_review'
    return json.loads((folder / 'jungle.json').read_text()), folder


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game-root', type=Path, required=True)
    p.add_argument('--geometry', type=Path, required=True, help='L4_HJ geometry.json (the input of the published Jungle scene)')
    p.add_argument('--material-root', type=Path, required=True, help='Jungle compatibility material root (prepare_jungle_review.py)')
    p.add_argument('--jungle-review', type=Path, required=True, help='published jungle_review folder (jungle.json)')
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    game = a.game_root.resolve()
    sys.path.insert(0, str(TOOLS))
    from verify_actor_item_grants import source_area
    from build_game_atlas import parse_mix, section
    import audit_game_transition_owners as A
    from lol2 import map_props as props
    from prepare_hive_wax import entry, sections, rgb_palette, decode_rows, digest, u32
    from PIL import Image

    area, arc, item, raw, owners, streams = source_area('L4_HJ', game)
    def cmds(stream, group): return [c['raw_hex'] for c in streams[stream][group]]
    def head(o): return arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]].hex()
    rock = {o['group']: o for o in owners if o['owner_kind'] == 'prop' and o['owner'] == ROCK and o['event'] == 9}
    assert sorted(rock) == [G_BREAK, G_HIT] and all(rock[g]['value'] == 0x0906 and rock[g]['predicate'] == 206 for g in rock)
    assert {g: head(rock[g]) for g in rock} == RECORDS
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    from prepare_jungle_exit_encounter import predicate
    cond = predicate(table, 206)
    assert (cond['op'], cond['left'], cond['right']) == ('==', {'owner_state': True}, {'immediate': 0}), cond
    hit = cmds(1, G_HIT)
    assert hit == HIT_COMMANDS
    brk = cmds(1, G_BREAK)
    assert len(brk) == 96
    movers = [mover(c) for c in brk if c.startswith('c4')]
    rest = [c for c in brk if not c.startswith('c4')]
    assert rest == ['c590bf110500', '090347001500', '020100000b05', '020100000b05', '0e03920a03000000', '0903fa000800',
                    'd090000000020300', '1403fa00cf02ff000a14'] + ['0903%02x%02x0200' % (n & 255, n >> 8) for n in
                    [2239, 2242, 2233, 2238, 2237, 2241, 2235, 2236, 2240, 2234]] + ['1003fa000100', '0503fa000200'], rest
    mouth = [m for m in movers if m['region'] == BURROW_MOUTH]
    channel = [m for m in movers if m['region'] != BURROW_MOUTH]
    assert mouth == [dict(region=BURROW_MOUTH, target=-70, relative=False, speed=3)]
    assert len(channel) == 75 and all(m['relative'] and m['speed'] == 3 and m['target'] in (-20, -50) for m in channel)
    assert sum(m['target'] == -50 for m in channel) == 66
    timer = [o for o in owners if o['owner_kind'] == 'prop' and o['owner'] == TIMER_PROP]
    assert len(timer) == 1 and timer[0]['event'] == 2 and timer[0]['group'] == G_TIMER and head(timer[0]) == TIMER_RECORD
    assert cmds(1, G_TIMER) == TIMER_COMMANDS
    t = bytes.fromhex(TIMER_RECORD)
    timer_info = dict(value=struct.unpack_from('<H', t, 4)[0], stopped=bool(t[5] & 1), range_high=t[6], range_low=t[7],
                      countdown=struct.unpack_from('<H', t, 8)[0], ticks_per_second=60)
    stones_owner = [o for o in owners if o['owner_kind'] == 'prop' and o['owner'] == STONE_TRIGGER]
    assert len(stones_owner) == 1 and (stones_owner[0]['event'], stones_owner[0]['value'], stones_owner[0]['group']) == (6, 20, G_STONES)
    stone_cmds = cmds(1, G_STONES)
    assert len(stone_cmds) == 37 and all(c.startswith('0903') and c.endswith('1314') for c in stone_cmds)
    stones = sorted(int(c[6:8] + c[4:6], 16) for c in stone_cmds)

    # Region kind11 event5 (floor movement end) on every relative channel region: op204 own region, preset 2.
    region_ofs, _, region_events = section(raw, 0x38, 0x80, 1)
    desc_ofs, desc_count, descriptors = section(raw, 0xa4, 0xac, 26)
    ends = {}
    for off in set(struct.unpack_from('<H', descriptors, i * 26 + 10)[0] for i in range(desc_count)):
        for cursor, kind, body, pred in A.events(region_events, off):
            if kind != 11: continue
            group, region, event, value = struct.unpack_from('<HHBB', body, 2)
            if region in {m['region'] for m in channel}: ends.setdefault(region, []).append((event, value, pred, cmds(0, group)))
    for m in channel:
        r = m['region']
        assert ends.get(r) == [(5, 0, None, ['cc90%02x%02xffff0200' % (r & 255, r >> 8)])], (r, ends.get(r))

    with tempfile.TemporaryDirectory(prefix='river-dam-') as temp:
        temp = Path(temp)
        geometry = json.loads(a.geometry.read_text())
        initial, initial_dir = scene(game, a.geometry, a.material_root, temp / 'initial')
        published = json.loads((a.jungle_review / 'jungle.json').read_text())
        assert initial['faces'] == published['faces'], 'jungle review differs from its regenerated scene'
        drained = copy.deepcopy(geometry)
        for m in movers:
            r = drained['regions'][m['region']]
            r['floor_corners'] = [c + m['target'] if m['relative'] else m['target'] for c in r['floor_corners']]
            r['floor_base'] = r['floor_base'] + m['target'] if m['relative'] else m['target']
            if m['relative']:
                words = list(struct.unpack('<22H', bytes.fromhex(r['raw_hex'])))
                words[16] = (words[16] & 0xFF00) | 2
                r['raw_hex'] = struct.pack('<22H', *words).hex()
        (temp / 'drained.json').write_text(json.dumps(drained))
        final, final_dir = scene(game, temp / 'drained.json', a.material_root, temp / 'final')
        dynamic = sorted(m['region'] for m in movers)
        chief = json.loads((a.project / 'assets/lol2/generated/jungle_chief_hut/source.json').read_text())['dynamic_regions']
        assert not set(dynamic) & set(chief), 'chief hut floors overlap'
        key = lambda f: json.dumps(f, sort_keys=True)
        final_keys = {key(f) for f in final['faces']}
        initial_keys = {key(f) for f in initial['faces']}
        floors = {}
        for f in initial['faces']:
            if f['kind'] == 'floor' and f['region'] in dynamic: floors.setdefault(str(f['region']), {})['initial'] = f
        for f in final['faces']:
            if f['kind'] == 'floor' and f['region'] in dynamic: floors.setdefault(str(f['region']), {})['final'] = f
        assert len(floors) == 76 and all(len(v) == 2 for v in floors.values())
        before = [i for i, f in enumerate(initial['faces']) if f['kind'] == 'wall' and key(f) not in final_keys]
        after = [f for f in final['faces'] if f['kind'] == 'wall' and key(f) not in initial_keys]
        changed_floors = [i for i, f in enumerate(initial['faces']) if f['kind'] == 'floor' and key(f) not in final_keys]
        assert sorted(initial['faces'][i]['region'] for i in changed_floors) == dynamic
        out = a.project / 'assets/lol2/generated/jungle_river_dam'
        if out.exists(): shutil.rmtree(out)
        out.mkdir(parents=True)
        used = {str(f['material']) for f in [initial['faces'][i] for i in before] + after if 'material' in f}
        used |= {str(v[s]['material']) for v in floors.values() for s in v if 'material' in v[s]}
        materials = {}
        for k in sorted(used):
            name = final['materials'].get(k) or initial['materials'][k]
            folder = final_dir if k in final['materials'] else initial_dir
            shutil.copyfile(folder / name, out / name)
            materials[k] = name

    # Sprites (template selectors, as the chief hut pack): rock selectors 0..2, foam, stones, timer tree, prop71.
    _, _, placements = section(raw, 0x14, 0x60, 37)
    meta = next(e for e in parse_mix(arc) if e['key'] == 3710142494)
    templates = props.load_templates(arc[meta['offset']:meta['offset'] + meta['size']])['templates']
    map_root = a.geometry.resolve().parent.parent
    tex = (map_root / 'materials/texture.bin').read_bytes()
    report = json.loads((map_root / 'materials/materials.json').read_text())
    assert hashlib.sha256(tex).hexdigest() == report['source_hash']['decoded_texture_sha256']
    sec = props.mm.sections(tex)
    palette_at = props.u32(tex, 4)
    rgb = props.mm.rgb_palette(tex[palette_at:palette_at + 768], 6)
    sprite_dir = out / 'sprites'; sprite_dir.mkdir()
    cache = {}
    def placement(n):
        r = placements[n * 37:(n + 1) * 37]
        x, z, heading, y = struct.unpack_from('<hhHh', r)
        region = next(row['region'] for row in exported if row['record'] == n)
        obj = dict(id=n, position=[x, y, -z], template=r[32], durability=r[30], region=region, selectors=[])
        for selector in templates[r[32]]['selectors']:
            frame = selector['frames'][0]
            image = props.build_image(frame['descriptor'], tex, sec, rgb, sprite_dir, out, cache)
            obj['selectors'].append(dict(selector=selector['selector'], descriptor=frame['descriptor'],
                                         frames=[str(Path(f)) for f in image.get('frames', [image['image']])], left=frame['left'],
                                         right=frame['right'], bottom=frame['bottom'], top=selector['state_height'] - frame['top_trim']))
        return obj
    with tempfile.TemporaryDirectory(prefix='river-dam-props-') as temp:
        exported = props.export_props(game, 'L4_HJ', Path(temp) / 'props', material_root=Path(temp) / 'materials')['props']
    # Unscripted ground cover standing in the moving regions (drawn by jungle_props.gd; settled with the floor).
    scripted_here = {ROCK, TIMER_PROP, STONE_TRIGGER, *FOAM, *stones}
    cover = sorted([row['record'], row['region']] for row in exported if row['region'] in {m['region'] for m in movers} and row['record'] not in scripted_here)
    published_cover = {int(i[3]) for g in json.loads((a.project / 'assets/lol2/generated/jungle_props/props.json').read_text())['groups'] for i in g['instances']}
    cover = [c for c in cover if c[0] in published_cover]
    objects = dict(rock=placement(ROCK), timer=placement(TIMER_PROP), trigger=placement(STONE_TRIGGER),
                   foam=[placement(n) for n in FOAM], stones=[placement(n) for n in stones])
    assert objects['rock']['template'] == 113 and objects['rock']['durability'] == 50 and len(objects['rock']['selectors']) == 3
    assert objects['rock']['position'] == [-4671, -70, -3499] and objects['timer']['template'] == 30

    # Burrow world items (same decode as tools/prepare_jungle_world_items.py; rows stay in its saved history).
    definitions = entry('GLOBAL.MIX', 3984507021)
    graphics = entry('LOCAL.MIX', 4018716831)
    base, count = u32(definitions, 4), u32(definitions, 0x34)
    state = base + count * 91 + 4; view = state + u32(definitions, state - 4) * 16 + 4; names = view + u32(definitions, view - 4) * 12
    first = {}; state_index = view_index = 0
    for index in range(count):
        record = definitions[base + index * 91:][:91]
        for sel in range(record[46] + record[47]):
            views = max(1, struct.unpack_from('<b', definitions, state + state_index * 16 + 13)[0])
            if sel == 0: first[index] = struct.unpack_from('<h', definitions, view + view_index * 12)[0]
            state_index += 1; view_index += views
    by_identity = {u32(definitions[base + i * 91:][:91], 24): i for i in range(count)}
    sec_g = sections(graphics); palette = rgb_palette(graphics[u32(graphics, 4):][:768], 6)
    burrow_regions = set()
    items = []
    for r in ITEM_ROWS:
        row = raw[u32(raw, 0x20) + 37 * r:][:37]
        x, y, _, z = struct.unpack_from('<hhHh', row); flags, region = struct.unpack_from('<HH', row, 8); identity = u32(row, 32)
        assert flags == 2
        d = by_identity[identity]; name = definitions[names + d * 30:names + d * 30 + 24].split(b'\0')[0].decode()
        resource = first[d]
        desc = struct.unpack_from('<6H11I', graphics, sec_g[2] + resource * 56)
        width, height, pixels, _ = decode_rows(graphics[sec_g[3] + desc[7]:][:desc[12]], allow_special=True)
        rgba = bytes(c for px in pixels for c in (*palette[px * 3:px * 3 + 3], 0 if px in (0, 1) else 255))
        stem = name.split('-', 1)[1].strip().replace(' ', '_')
        icon = f'item{r}_{stem.lower()}.png'; Image.frombytes('RGBA', (width, height), rgba).save(out / icon)
        items.append(dict(row=r, id=f'jungle:item{r}:{stem}', name=name, label=name.split('-', 1)[1].strip(), position=[x, z, -y],
                          region=region, definition=d, handler=definitions[base + d * 91 + 0x42], icon='res://assets/lol2/generated/jungle_river_dam/' + icon))
        burrow_regions.add(region)
    assert [i['name'].strip() for i in items] == ['57a-Fire crstl', '57a-Fire crstl', '65a-Storm', '66-Ancients stn', '66-Ancients stn', '66-Ancients stn', '136-SS3']
    def polygon(n):
        reg = geometry['regions'][n]
        return dict(id=n, polygon=[[geometry['vertices_fixed'][v][0] / 65536, -geometry['vertices_fixed'][v][1] / 65536] for v in reg['vertex_indices']],
                    floor=min(reg['floor_corners']), ceiling=max(reg['ceiling_corners']))
    burrow = sorted(n for n in range(len(geometry['regions'])) if n != BURROW_MOUTH and min(geometry['regions'][n]['ceiling_corners']) == -50
                    and min(geometry['regions'][n]['floor_corners']) == -70)
    burrow = [n for n in burrow if n in range(2739, 2748) or n in range(4526, 4543)]
    assert len(burrow) == 26 and burrow_regions <= set(burrow)
    # Walk route for the reachability test: drained channel region2429 -> pit2413 -> mouth4543 -> burrow -> item rooms.
    allowed = {m['region'] for m in movers} | {2413} | set(burrow)
    def route_to(goal, start=2429):
        prev = {start: None}; queue = [start]
        while queue:
            n = queue.pop(0)
            for m in geometry['regions'][n]['neighbors']:
                if m is not None and m in allowed and m not in prev: prev[m] = n; queue.append(m)
        path = [goal]
        while prev[path[-1]] is not None: path.append(prev[path[-1]])
        return path[::-1]
    route = route_to(2742)
    assert route[:3] == [2429, 2413, BURROW_MOUTH], route
    result = dict(version=1, archive='DAT/L4_HJ.MIX', source_sha256=area['source']['sha256'],
                  rock=dict(records=RECORDS, durability=50, masks=[0x0906, 0x0004], break_threshold=1, hit_commands=HIT_COMMANDS,
                            break_commands=brk, predicate='owner state == 0'),
                  movers=movers, speed_units_per_second=2.5, mud_preset=2,
                  floors=floors, walls_before=before, walls_after=after, materials=materials,
                  objects=objects, stones=stones, cover=cover, timer=dict(timer_info, commands=TIMER_COMMANDS, form=2, duration_low=120, duration_high=180),
                  rewards=dict(property=0x0B, awards=[500, 500]), items=items,
                  burrow=dict(mouth=polygon(BURROW_MOUTH), regions=[polygon(n) for n in burrow], route=[polygon(n) for n in route]),
                  not_hosted=['op208 screen shake', 'op9 prop250 properties 8/16', 'property19 = 20 on the 37 stones (no hit records)',
                              'foam event6 sounds'],
                  scope='Rock, its hits and break, the drained river (floors, mud, walls), timer tree and timed lizard form, '
                        'burrow items. Original sprites, sounds as request ids only.')
    # Hit (956) and break (719) sound requests through the shared creature sound bank reader.
    from prepare_creature_audio_clips import stage_clips, BANK_HASH
    audio = a.project / 'assets/lol2/generated/jungle_river_dam_audio'
    if audio.exists(): shutil.rmtree(audio)
    clips = stage_clips(a.project, 'jungle_river_dam_audio', [956, 719], game=game)
    (audio / 'audio.json').write_text(json.dumps({'sound_bank_sha256': BANK_HASH, 'clips': clips}, indent=2) + '\n')
    result['audio'] = 'res://assets/lol2/generated/jungle_river_dam_audio/'
    (out / 'source.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS jungle river dam: {len(movers)} movers, {len(before)} walls before / {len(after)} after, {len(materials)} materials, '
          f'{len(stones)} stones, {len(items)} burrow items, timer countdown {timer_info["countdown"]}')


if __name__ == '__main__':
    main()
