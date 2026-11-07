#!/usr/bin/env python3
"""Pin the L1_DC colonnade pillar trap (playtest 2026-10-17 report 10:58:48, "2 pillars that you can hit and bring
down the stones on the guard pursuing you") from the original archive records.

Colonnade (corridor regions 1948/1952/0/1934/1947/1929/1946/1941/1945, x -544..-407): six intact template30 pillars
(props 1213-1218, descriptor15) and one cracked template31 pillar, prop878 (selector0 descriptor11 two frames,
selector1 descriptor13 broken stump, durability byte30 = 2). Neither template is in the legacy static preview set and
878 is animated, so none of the seven pillars was drawn.
  prop878 kind4 value0 (use) at state0, g8416: op20 sound955, op16 state1, op7 (2,0) (0,0).
  prop878 kind9 g8478 masks 0x0906/0x0004 (melee) and g8556 masks 0x0011/0x0001 (Spark), threshold1 mode4, both
    local9==1 AND local24==0: local24=1, local31=0 (melee) / 1 (Spark), two op18 on prop19 (flags word 0x0009,
    bit 0x20 clear: no queued command, as prop83 g146), op9 prop19 property14 x2 (not hosted), op9 property21 on
    props 152 and 150 (event20).
  prop878 kind6 event20 g8450: op20 sound955, op7 (2,0) (0,0).
  prop150 event20 (local31 x local11, shared scenic local11): melee first solve op2 sub0x0F +1 fighting level, later
    sub9 arg5 (50); Spark first solve sub0x10 +1 magic level, later sub0x0A arg7 (70).
  prop152 event20 at state0 by local6 (guard38's region, below): local14=1, op9 movable4 property3 (link), op8
    movable4 0 then 2, op5 prop878 selector1, op20 392/379 on movable4, op14 prop151 sub4 (stop); local6==0 adds
    five op13 on actor38 (not hosted); local6==1 first runs op2 sub0x0C arg2 (magic 200) and sub0x0B arg2
    (fighting 200) and op16 actor38 state1 (actor38 kind6 value3 at state1: sound768 on prop17, op13 sub6, op5
    selector8 (GGUARD death), op16 state2 -> kind6 value3 at state2: op9 property2 unlink).
  Regions (player): 1929 event2 local9=1, 1947 event2 local9=0, 120/234/283 event4 (local24==0) local24=1 and op9
    prop152 property21 (the corridor collapses when the player leaves south); 1787 event2 op14 prop151 sub3 start,
    1785/1788/1793 event2 op14 sub4 stop.
  actor38 kind10 value0x9000 (actor enters region word, local24==0): 1934/0/1952 local6=1, 1947/1929 local6=2,
    1948 local6=0.
  movable4: template22 rubble (material312, alpha cutout), travel 0 (does not move), two faces across the corridor
    at y -10915/-10920; unlinked until prop152.
  prop151: kind2 timer flags0x10 (random(byte7..byte6) = 5..15 seconds), disabled; event: op23 state random(0..4),
    op9 self property21; event20 at state n: op208 region1945 (shake, not hosted) and op9 property21 on one of
    props 1222/1223/1224/1225/1221 (template29 falling pebbles, descriptor419 30 frames), each running op20 on
    prop878, op9 prop878 property21 and op7 (2,0) (0,0) on itself.
Usage: prepare_cave_pillar_trap.py --output scripts/lol2/cave_pillar_trap_source.json
"""
import argparse, hashlib, json, shutil, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('~/lol2_out/all_maps_20260922/L1_DC')
STATIC = [1213, 1214, 1215, 1216, 1217, 1218]
PILLAR = 878
STONES = [1221, 1222, 1223, 1224, 1225]
TIMER, REWARD, COLLAPSE, MOVABLE, GUARD, CRUSH_SOUND_PROP = 151, 150, 152, 4, 38, 17
SOUNDS = [955, 696, 697, 698, 392, 379, 768]
PLAYER_REGIONS = {1929: ('local9', 1), 1947: ('local9', 0), 120: ('collapse', 1), 234: ('collapse', 1),
                  283: ('collapse', 1), 1787: ('timer', 3), 1785: ('timer', 4), 1788: ('timer', 4), 1793: ('timer', 4)}
GUARD_REGIONS = {1934: 1, 0: 1, 1952: 1, 1947: 2, 1929: 2, 1948: 0}


def le(n):
    return struct.pack('<H', n).hex()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    out = ROOT / 'assets/lol2/generated/cave_pillar_trap'
    if out.exists(): sys.exit('refusing to overwrite ' + str(out))
    sys.path.insert(0, str(Path(__file__).resolve().parent / 'lol2'))
    from map_props import load_templates
    from lol2_source_format import parse_mix
    area, arc, entry, raw, owners, streams = source_area('L1_DC')
    meta = next(arc[e['offset']:e['offset'] + e['size']] for e in parse_mix(arc) if e['key'] == 2971019266)
    templates = load_templates(meta)['templates']
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    exported = {q['record']: q for q in json.loads((MAP / 'props/props.json').read_text())['props']}
    review = json.loads((MAP / 'review.json').read_text())
    geometry = json.loads((MAP / 'geometry/geometry.json').read_text())
    movables = json.loads((MAP / 'movables/movables.json').read_text())

    def records(kind, owner):
        rows = []
        for o in owners:
            if o['owner_kind'] != kind or o['owner'] != owner: continue
            r = arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]]
            rows.append(dict(group=o['group'], kind=o['event'], raw=r.hex(),
                             predicate=predicate(table, o['predicate']) if o['predicate'] is not None else None,
                             commands=[c['raw_hex'] for c in streams[o['stream']][o['group']]]))
        return rows

    def cmds(kind, owner):
        return [(r['kind'], r['raw'], r['commands']) for r in records(kind, owner)]

    oid = le(PILLAR)
    # Pillar 878: byte-exact record set.
    pillar_rows = records('prop', PILLAR)
    assert cmds('prop', PILLAR) == [
        (4, '0a04e020000000000000', ['1403%sbb0396111f0f' % oid, '1003%s0100' % oid, '0703%s0200' % oid, '0703%s0000' % oid]),
        (6, '06060221143c', ['1403%sbb0396001f0f' % oid, '0703%s0200' % oid, '0703%s0000' % oid]),
        (9, '0a091e21060904000104', ['c60000001801', 'c60000001f00', '12031300f3fdc42b00000900000000190000', '12031300f3fdc42b00000900000000190000', '090313000e00', '090313000e00', '090398001500', '090396001500']),
        (9, '0a096c21110001000104', ['c60000001801', 'c60000001f01', '12031300f3fdc42b00000900000000140000', '12031300f3fdc42b00000900000000140000', '090313000e00', '090313000e00', '090396001500', '090398001500']),
    ], cmds('prop', PILLAR)
    for c in pillar_rows[2]['commands'] + pillar_rows[3]['commands']:
        if c.startswith('12'): assert not struct.unpack_from('<H', bytes.fromhex(c), 10)[0] & 0x20  # B59CE: no queue
    # Stones: event20 only, op20 on 878, event20 to 878, op7 play on itself.
    stones = {}
    for s in STONES:
        rows = records('prop', s); q = exported[s]
        assert q['template'] == 29 and q['animated'] and len(rows) == 1 and rows[0]['kind'] == 6 and rows[0]['raw'][8:10] == '14', s
        c = rows[0]['commands']
        assert c[0].startswith('1403%s' % oid) and c[1:] == ['0903%s1500' % oid, '0703%s0200' % le(s), '0703%s0000' % le(s)], (s, c)
        stones[str(s)] = dict(position=q['position'], region=q['region'], left=q['left'], right=q['right'], bottom=q['bottom'], top=q['top'], sound=struct.unpack_from('<H', bytes.fromhex(c[0]), 4)[0])
    # Timer prop151: kind2 then event20 at state n -> op208 region1945, event20 on one stone.
    timer_rows = records('prop', TIMER)
    t = bytes.fromhex(timer_rows[0]['raw'])
    assert timer_rows[0]['kind'] == 2 and timer_rows[0]['commands'] == ['1703%s0500' % le(TIMER), '0903%s1500' % le(TIMER)]
    assert t[4] == 0x10 and t[5] & 1 and (t[7], t[6]) == (5, 15), t.hex()
    order = {}
    for r in timer_rows[1:]:
        assert r['kind'] == 6 and r['raw'][8:10] == '14' and r['predicate']['left'] == {'owner_state': True}
        c = r['commands']; assert len(c) == 2 and c[0].startswith('d0909907') and c[1].endswith('1500')
        order[str(r['predicate']['right']['immediate'])] = dict(stone=struct.unpack_from('<H', bytes.fromhex(c[1]), 2)[0],
                                                                 shake=[bytes.fromhex(c[0])[5], bytes.fromhex(c[0])[6]])
    assert sorted(v['stone'] for v in order.values()) == STONES and sorted(order) == ['0', '1', '2', '3', '4']
    # Reward prop150 and collapse prop152 event20 groups (kept verbatim for the runtime interpreter).
    reward_rows = records('prop', REWARD); collapse_rows = records('prop', COLLAPSE)
    assert len(reward_rows) == 4 and all(r['kind'] == 6 and r['raw'][8:10] == '14' for r in reward_rows)
    assert sorted(r['commands'][-1] for r in reward_rows) == ['020100000905', '020100000a07', '020100000f01', '020100001001']
    assert len(collapse_rows) == 3 and all(r['kind'] == 6 and r['raw'][8:10] == '14' for r in collapse_rows)
    for r in collapse_rows:
        c = r['commands']
        for need in ['c60000000e01', '092004000300', '0820040000000000', '0820040002000000', '0503%s0100' % oid,
                     '142004008801ff11320c', '142004007b01ff11320c', '0e03970004000000']: assert need in c, (r['group'], need)
    # Guard38: kind10 region words -> local6, kind6 crush chain.
    guard_rows = records('actor', GUARD)
    k10 = {}
    for r in guard_rows:
        if r['kind'] != 10: continue
        b = bytes.fromhex(r['raw']); assert b[4:6] == bytes([0, 0x90]) and len(r['commands']) == 1 and r['commands'][0][:10] == 'c600000006'
        assert r['predicate'] == {'op': '==', 'left': {'local': 24}, 'right': {'immediate': 0}, 'raw': '0003180000'}
        k10[struct.unpack_from('<H', b, 6)[0]] = int(r['commands'][0][10:12], 16)
    assert k10 == GUARD_REGIONS, k10
    crush = [r for r in guard_rows if r['kind'] == 6]
    assert [r['commands'] for r in crush] == [['140311000003ff001919', '0d02260006000000', '050226000800', '100226000200'], ['090226000200']]
    # Player regions.
    region_rows = {}
    for rid, (role, value) in PLAYER_REGIONS.items():
        rows = records('region', rid); assert len(rows) == 1, rid
        r = rows[0]; c = r['commands']
        if role == 'local9': assert r['kind'] == 2 and c == ['c60000000901' if value else 'c60000000900']
        elif role == 'collapse': assert r['kind'] == 4 and c == ['c60000001801', '090398001500'] and r['predicate']['left'] == {'local': 24}
        else: assert r['kind'] == 2 and c == ['0e039700%02x000000' % value]
        region_rows[str(rid)] = dict(role=role, value=value, kind=r['kind'], group=r['group'])

    def polygon(rid):
        reg = geometry['regions'][rid]; v = geometry['vertices_fixed']
        return dict(polygon=[[v[i][0] / 65536, -v[i][1] / 65536] for i in reg['vertex_indices']],
                    floor_min=min(reg['floor_corners']), floor_max=max(reg['floor_corners']))
    for rid in region_rows: region_rows[rid].update(polygon(int(rid)))
    guard_regions = {str(k): dict(local6=v, **polygon(k)) for k, v in GUARD_REGIONS.items()}
    # Movable4 rubble.
    rubble = [f for f in movables['faces'] if f['placement'] == MOVABLE]
    place = next(x for x in movables['placements'] if x['index'] == MOVABLE)
    assert len(rubble) == 2 and all(f['resource_id'] == 312 for f in rubble) and place['motion_bytes_hex'] == '0100010001000000'
    assert records('movable', MOVABLE)[0]['commands'][:2] == ['092004000d00', '0820040001000000']
    # Art.
    out.mkdir(parents=True)

    def stage(src, name):
        shutil.copyfile(src, out / name); return name
    T31 = templates[31]; T30 = templates[30]; T29 = templates[29]
    assert [s['frames'][0]['descriptor'] for s in T31['selectors']] == [11, 13] and T30['selectors'][0]['frames'][0]['descriptor'] == 15
    assert T29['selectors'][0]['frames'][0]['descriptor'] == 419

    def bounds(T, sel):
        s = T['selectors'][sel]; f0 = s['frames'][0]
        return dict(left=f0['left'], right=f0['right'], bottom=f0['bottom'], top=s['state_height'] - f0['top_trim'])
    art = {
        'pillar': [dict(selector=0, frames=[stage(MAP / f.replace('.png', '_index.png'), f'11_{i}_index.png') for i, f in enumerate(review['animations']['prop_11']['frames'])], **bounds(T31, 0)),
                   dict(selector=1, frames=[stage(MAP / 'props/sprites/prop_13_index.png', '13_0_index.png')], **bounds(T31, 1))],
        'static': dict(frames=[stage(MAP / 'props/sprites/prop_15_index.png', '15_0_index.png')], **bounds(T30, 0)),
        'stone': dict(frames=[stage(MAP / f.replace('.png', '_index.png'), f'419_{i}_index.png') for i, f in enumerate(review['animations']['prop_419']['frames'])], **bounds(T29, 0)),
        'rubble': stage(MAP / 'materials/material_0312/mip_0_indices.png', 'rubble_312_index.png'),
    }
    assert len(art['pillar'][0]['frames']) == 2 and len(art['stone']['frames']) == 30
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_creature_audio_clips import stage_clips
    stage_clips(ROOT, 'cave_pillar_trap', SOUNDS)
    import wave
    sounds = {}
    for s in SOUNDS:
        with wave.open(str(out / f'{s}.wav')) as w: sounds[str(s)] = dict(file=f'{s}.wav', seconds=round(w.getnframes() / w.getframerate(), 4))
    files = {n.name: hashlib.sha256(n.read_bytes()).hexdigest() for n in sorted(out.iterdir())}
    # Per-placement bounds from the exported placement (region-height rule for flag2 templates, frame trims).
    def placed(r):
        e = exported[r]; return dict(position=e['position'], region=e['region'], left=e['left'], right=e['right'], bottom=e['bottom'], top=e['top'])
    statics = {str(r): placed(r) for r in STATIC}
    assert all(exported[r]['template'] == 30 and not exported[r]['animated'] for r in STATIC)
    q = exported[PILLAR]
    result = dict(
        version=1, source=dict(area='L1_DC', archive_sha256=hashlib.sha256(arc).hexdigest()),
        art=art, statics=statics,
        pillar=dict(id=PILLAR, position=q['position'], region=q['region'], left=q['left'], right=q['right'], bottom=q['bottom'], top=q['top'], durability=bytes.fromhex(q['placement_hex'])[30],
                    height=struct.unpack_from('<H', bytes.fromhex(T31['template_hex']), 28)[0],
                    depth=struct.unpack_from('<H', bytes.fromhex(T31['template_hex']), 30)[0], records=pillar_rows),
        stones=stones, timer=dict(id=TIMER, flags=t[4], enabled=not (t[5] & 1), range_seconds=[t[7], t[6]], random_states=5, order=order),
        reward=dict(id=REWARD, records=reward_rows), collapse=dict(id=COLLAPSE, records=collapse_rows),
        guard=dict(actor=GUARD, regions=guard_regions, crush_sound=768, crush_sound_prop=dict(id=CRUSH_SOUND_PROP, position=exported[CRUSH_SOUND_PROP]['position']),
                   magic_award=200, fighting_award=200),
        player_regions=region_rows,
        rubble=dict(movable=MOVABLE, faces=[dict(points=f['points']) for f in rubble], sounds=[392, 379]),
        sounds=sounds, files=files,
        adapters=['timer reload random 5..15 s from the port RNG, not the native 12415C state; op23 state from the same RNG',
                  'op7 (2,0),(0,0) plays one pass from frame0 then holds frame0 (cave_side_chamber convention), 10 frames/s',
                  'hit volume = selector0 width x template height(byte28) x depth(byte30), as the scenic prop574 rule',
                  'guard38 crush: health set to 0 with no hit reward (the op2 awards are the reward), GGUARD death clip '
                  '(selector8 = native op5 selector8) then the shared corpse; native unlink at state2 is not mirrored',
                  'rubble collision = convex hull of its two faces; faces drawn at once on link (travel 0, op8 media start '
                  'has no proven picture change)',
                  'region event2/event4 = player entry edge (floor-qualified), as the side-chamber and curse owners'],
        not_hosted=['op208 screen shake (prop151 event20, region1945)', 'op9 prop19 property14 and op18 on prop19 (no queue)',
                    'local6==0 op13 commands on actor38 (unresolved creature sub-ops)', 'local14 (no reader found in L1_DC predicates)'])
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS cave pillar trap: 7 pillars, %d stones, %d player regions, %d guard regions, %d art files, %d sounds' %
          (len(stones), len(region_rows), len(guard_regions), len(files) - len(SOUNDS), len(SOUNDS)))


if __name__ == '__main__':
    main()
