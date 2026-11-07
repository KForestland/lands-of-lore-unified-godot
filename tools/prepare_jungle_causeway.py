#!/usr/bin/env python3
"""Stage the Huline Jungle causeway collapse (L4_HJ prop4648 event20, group17352) for scripts/lol2/jungle_causeway.gd.

Source (verify_actor_item_grants.source_area L4_HJ; every pin below is asserted; Codex
AI_COMMS/codex_act1_review_20261025/causeway_source_check.json):
  All three exit endings (prop4398 groups 16986/17076/17160) run op9 prop4648 property21 (090328121500): event20 to
  prop4648, whose only record (kind6 value20, no predicate) is g17352, in order:
    op197 regions 4429/4448/4447 sub3 (set region bit1, creature refusal), op9 controls 62/61 property3 (link),
    op9 control84 property2 (unlink), op9 prop4162 property2, op18 props 4161/508/506/4181/4160 (moves), op9 props
    507/509 property2, op208 shake, op198 local43 = 1, op1 movables 62/59/63/60 -> 100 percent, op18 movables
    59/63/60/62, op196 region4445 by -20 (relative, speed 25), op204 preset 42 on 11 regions, op196 12 regions to
    -200 (absolute, speed 244).
  Floor movers and presets follow the river dam recipe: mover c4 90 region target flags(bit0 ceiling, bit3 relative)
  speed; op204 cc 90 region ffff preset (region word16 low byte = floor preset selector).
Geometry: the Jungle scene is regenerated with tools/prepare_jungle_review.py from the same inputs, once as published
(must equal --jungle-review) and once with the movers and presets applied (the collapsed causeway). Changed floors and
the wall faces that differ are handed to the runtime host.
Output: PROJECT/assets/lol2/generated/jungle_causeway/{source.json, PNGs}.
Usage: prepare_jungle_causeway.py --game-root GAME --geometry GEOMETRY --material-root MATERIALS --jungle-review REVIEW
       [--project PROJECT]
"""
import argparse, copy, hashlib, json, shutil, struct, sys, tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
OWNER, GROUP, CALL = 4648, 17352, '090328121500'
ENDINGS = [16986, 17076, 17160]
COMMANDS = ('c5904d110300 c59060110300 c5905f110300 09103e000300 09103d000300 091054000200 090342100200 '
            '12034110da163a0ffcfe850a4f9a00140000 1203fc018316330ffcfe850a4f9a00140000 0903fb010200 '
            '1203fa01d1167b0efcfe850a4f9a00140000 0903fd010200 12035510e316560efcfe850a4f9a00140000 '
            '1203401092160e0efcfe850a4f9a00140000 d090000000020200 c60000002b01 01203e006400 01203b006400 01203f006400 '
            '01203c006400 12203b006514ff0afcfe090b4f9a00140000 12203f006110a011fcfe090b8848000a0000 '
            '12203c0064111a0bfcfe090b2242000f0000 12203e006a130e12fcfe090b4484000c0000 c4905d11ecff081900000000 '
            + ' '.join('cc90%sffff2a00' % r for r in ['5f11', '6011', '4d11', '4c11', '5711', '5611', '5411', '5511', '4b11', '4a11', '5311'])
            + ' ' + ' '.join('c490%s38ff00f400000000' % r for r in ['5f11', '6011', '4d11', '4c11', '5711', '5611', '5411', '5511', '4b11', '4a11', '5311', '5211'])).split()
LINK, UNLINK = [62, 61], [84]
PROPS = [506, 507, 508, 509, 4160, 4161, 4162, 4181]


def mover(raw):
    b = bytes.fromhex(raw)
    assert b[0] == 0xC4 and b[1] == 0x90 and len(b) == 12, raw
    region, target = struct.unpack_from('<Hh', b, 2)
    assert not b[6] & 1, 'ceiling mover'
    return dict(region=region, target=target, relative=bool(b[6] & 8), speed=b[7])


def preset(raw):
    b = bytes.fromhex(raw)
    assert b[0] == 0xCC and b[1] == 0x90 and len(b) == 8 and b[4:6] == b'\xff\xff', raw
    return dict(region=struct.unpack_from('<H', b, 2)[0], preset=struct.unpack_from('<H', b, 6)[0])


def scene(game, geometry, materials, out):
    import subprocess
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
    from build_game_atlas import section

    area, arc, item, raw, owners, streams = source_area('L4_HJ', game)
    def cmds(stream, group): return [c['raw_hex'] for c in streams[stream][group]]
    rows = [o for o in owners if o['owner_kind'] == 'prop' and o['owner'] == OWNER]
    assert len(rows) == 1 and (rows[0]['stream'], rows[0]['group'], rows[0]['event'], rows[0]['value'], rows[0]['predicate']) == (1, GROUP, 6, 20, None), rows
    commands = cmds(1, GROUP)
    assert commands == COMMANDS, commands
    callers = sorted(g for s, groups in enumerate(streams) for g, cs in groups.items() if any(c['raw_hex'] == CALL for c in cs))
    assert callers == ENDINGS, callers
    for g in ENDINGS: assert cmds(1, g)[2] == CALL and cmds(1, g)[3].startswith('15032e11'), g  # event20 before each movie
    movers = [mover(c) for c in commands if c.startswith('c4')]
    presets = [preset(c) for c in commands if c.startswith('cc')]
    assert [m['region'] for m in movers if m['relative']] == [4445] and movers[0] == dict(region=4445, target=-20, relative=True, speed=25)
    assert all(m['target'] == -200 and m['speed'] == 244 for m in movers if not m['relative']) and len(movers) == 13
    assert len(presets) == 11 and {x['preset'] for x in presets} == {42} and {x['region'] for x in presets} < {m['region'] for m in movers}
    region_bit1 = [struct.unpack_from('<H', bytes.fromhex(c), 2)[0] for c in commands if c.startswith('c590') and c.endswith('0300')]
    assert region_bit1 == [4429, 4448, 4447]
    links = [struct.unpack_from('<H', bytes.fromhex(c), 2)[0] for c in commands if c.startswith('0910') and c.endswith('0300')]
    unlinks = [struct.unpack_from('<H', bytes.fromhex(c), 2)[0] for c in commands if c.startswith('0910') and c.endswith('0200')]
    assert links == LINK and unlinks == UNLINK
    _, _, controls = section(raw, 0x18, 0x64, 33)
    def control(n):
        r = controls[n * 33:(n + 1) * 33]; x, z, heading, h = struct.unpack_from('<hhHh', r)
        return dict(id=n, position=[x, h, -z], heading=heading, flags=struct.unpack_from('<H', r, 8)[0], template=r[32])
    presence = {str(n): control(n) for n in LINK + UNLINK}
    assert all(presence[str(n)]['flags'] & 0x1000 for n in LINK) and not presence['84']['flags'] & 0x1000, presence

    with tempfile.TemporaryDirectory(prefix='causeway-') as temp:
        temp = Path(temp)
        geometry = json.loads(a.geometry.read_text())
        initial, initial_dir = scene(game, a.geometry, a.material_root, temp / 'initial')
        published = json.loads((a.jungle_review / 'jungle.json').read_text())
        assert initial['faces'] == published['faces'], 'jungle review differs from its regenerated scene'
        collapsed = copy.deepcopy(geometry)
        for m in movers:
            r = collapsed['regions'][m['region']]
            r['floor_corners'] = [c + m['target'] if m['relative'] else m['target'] for c in r['floor_corners']]
            r['floor_base'] = r['floor_base'] + m['target'] if m['relative'] else m['target']
        for x in presets:
            r = collapsed['regions'][x['region']]
            words = list(struct.unpack('<22H', bytes.fromhex(r['raw_hex'])))
            words[16] = (words[16] & 0xFF00) | x['preset']
            r['raw_hex'] = struct.pack('<22H', *words).hex()
        # Region bit1 (op197 sub3): creature refusal over each region's collapsed floor .. source ceiling (word +22).
        creature_regions = []
        for n in region_bit1:
            r = collapsed['regions'][n]
            creature_regions.append(dict(id=n, raw=geometry['regions'][n]['raw_hex'], floor=min(r['floor_corners']),
                                         ceiling=struct.unpack_from('<h', bytes.fromhex(r['raw_hex']), 22)[0],
                                         polygon=[[geometry['vertices_fixed'][v][0] / 65536, -geometry['vertices_fixed'][v][1] / 65536] for v in r['vertex_indices']]))
        assert [(x['floor'], x['ceiling']) for x in creature_regions] == [(-200, -100), (-200, 127), (-200, -100)], creature_regions
        (temp / 'collapsed.json').write_text(json.dumps(collapsed))
        final, final_dir = scene(game, temp / 'collapsed.json', a.material_root, temp / 'final')
        dynamic = sorted(m['region'] for m in movers)
        for other in ('jungle_chief_hut', 'jungle_river_dam'):
            path = a.project / f'assets/lol2/generated/{other}/source.json'
            taken = json.loads(path.read_text())
            taken = taken['dynamic_regions'] if 'dynamic_regions' in taken else [int(k) for k in taken['floors']]
            assert not set(dynamic) & {int(r) for r in taken}, f'{other} floors overlap'
        key = lambda f: json.dumps(f, sort_keys=True)
        final_keys = {key(f) for f in final['faces']}
        initial_keys = {key(f) for f in initial['faces']}
        floors = {}
        for f in initial['faces']:
            if f['kind'] == 'floor' and f['region'] in dynamic: floors.setdefault(str(f['region']), {})['initial'] = f
        for f in final['faces']:
            if f['kind'] == 'floor' and f['region'] in dynamic: floors.setdefault(str(f['region']), {})['final'] = f
        assert len(floors) == len(dynamic) and all(len(v) == 2 for v in floors.values())
        before = [i for i, f in enumerate(initial['faces']) if f['kind'] == 'wall' and key(f) not in final_keys]
        after = [f for f in final['faces'] if f['kind'] == 'wall' and key(f) not in initial_keys]
        changed_floors = sorted({initial['faces'][i]['region'] for i, f in enumerate(initial['faces']) if f['kind'] == 'floor' and key(f) not in final_keys})
        # Regions already at -200 with preset 42 (4426/4428/4434/4438) keep their floor face.
        assert set(changed_floors) <= set(dynamic) and 4445 in changed_floors, changed_floors
        unchanged = sorted(set(dynamic) - set(changed_floors))
        out = a.project / 'assets/lol2/generated/jungle_causeway'
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
    # The eight scripted causeway props (template39, sprite 755; not drawn by jungle_props.gd): op9 property2 unlinks
    # 4162/507/509; op18 places 4161/508/506/4181/4160 (the player op18 layout: x, native y, height at bytes 4/6/8).
    from lol2 import map_props as props_module
    with tempfile.TemporaryDirectory(prefix='causeway-props-') as temp:
        export = props_module.export_props(game, 'L4_HJ', Path(temp) / 'props', material_root=Path(temp) / 'materials')
        prop_rows = {x['record']: x for x in export['props'] if x['record'] in PROPS}
        assert sorted(prop_rows) == PROPS and {x['material'] for x in prop_rows.values()} == {'prop_755'} and all(x['template'] == 39 for x in prop_rows.values())
        sprite = Path(temp) / 'props/sprites/prop_755.png'
        shutil.copyfile(sprite, out / 'prop_755.png')
        sprite_sha = hashlib.sha256(sprite.read_bytes()).hexdigest()
    actions = {}
    for c in commands:
        b = bytes.fromhex(c)
        if b[1] != 3 or struct.unpack_from('<H', b, 2)[0] not in PROPS: continue
        n = struct.unpack_from('<H', b, 2)[0]
        if b[0] == 9: assert b[4:6] == b'\x02\x00'; actions[n] = dict(action='unlink')
        elif b[0] == 18:
            # Native 65BB0 (AI_COMMS/act1_completion_20261017/CAUSEWAY_OP18_FLAGS_CHECK.md): flags 0x0a85 = teleport (bit
            # 0x04) to absolute x/y; the height word applies only with bit 0x100 (clear here), so the prop keeps its height.
            x, y, h = struct.unpack_from('<hhh', b, 4); flags = struct.unpack_from('<H', b, 10)[0]
            assert flags == 0x0A85 and flags & 0x04 and not flags & 0x100, c
            actions[n] = dict(action='move', target_xz=[x, -y], unused_height=h, teleport=True, raw=c)
    assert sorted(actions) == PROPS and sorted(n for n, x in actions.items() if x['action'] == 'unlink') == [507, 509, 4162]
    staged_props = []
    for n in PROPS:
        if actions[n]['action'] == 'move': actions[n]['target'] = [actions[n]['target_xz'][0], prop_rows[n]['position'][1], actions[n]['target_xz'][1]]
        x = prop_rows[n]; flags = struct.unpack_from('<H', bytes.fromhex(x['placement_hex']), 8)[0]
        staged_props.append(dict(record=n, position=x['position'], selector=x['selector'], left=x['left'], right=x['right'], bottom=x['bottom'],
                                 top=x['top'], image='prop_755.png', present=not flags & 0x1000, placement_hex=x['placement_hex'], **actions[n]))
    assert all(x['present'] for x in staged_props)
    result = dict(version=1, archive='DAT/L4_HJ.MIX', source_sha256=area['source']['sha256'],
                  geometry_sha256=hashlib.sha256(a.geometry.read_bytes()).hexdigest(),
                  owner=dict(prop=OWNER, kind=6, value=20, group=GROUP, predicate=None, archive_offset=rows[0]['archive_offset'], callers=ENDINGS, call=CALL),
                  commands=commands, movers=movers, presets=presets, region_bit1=region_bit1, creature_regions=creature_regions, link=LINK, unlink=UNLINK, presence=presence,
                  local43=1, props=staged_props, prop_sprite_sha256=sprite_sha, floors=floors, unchanged_floors=unchanged, walls_before=before, walls_after=after, materials=materials,
                  verified=['floor targets and presets (op196/op204) through the published scene builder', 'controls 61/62 link, 84 unlink',
                            'control84 native solid (static_collision_L4_HJ.json: template24 mode3 child47, 60 high) until it is unlinked',
                            'region bit1 on 4429/4448/4447 as creature refusal (creature_region_barrier.gd, modern refusal adapter)',
                            'props 507/509/4162 unlinked; props 4161/508/506/4181/4160 teleported to their op18 x/z at their own height (native 65BB0: bit 0x04, height only with 0x100)',
                            'local43 = 1', 'called once from each exit ending before its movie'],
                  modern=['floors are presented at their final height at once (native speeds 244 and 25 settle in about 0.1 and 0.3 s)',
                          'the collapse is applied when the ending queues it, before the movie; movie end and skip leave the same world'],
                  not_hosted=['op208 shake (content gap)',
                              'whether the native mover B286C runs for template39 props is not traced (CAUSEWAY_OP18_FLAGS_CHECK.md)',
                              'movables 59/60/62/63 travel to 100 percent and moves (movables not drawn by the port: content gap)'],
                  scope='Causeway collapse group17352: floors, presets, walls, control presence and control84 solid, region bit1 creature refusal, local43. '
                        'Not all 48 command effects: see not_hosted.')
    (out / 'source.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS jungle causeway: {len(movers)} movers, {len(presets)} presets, {len(before)} walls before / {len(after)} after, '
          f'{len(materials)} materials, links {LINK}, unlinks {UNLINK}')


if __name__ == '__main__':
    main()
