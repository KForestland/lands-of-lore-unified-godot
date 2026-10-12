#!/usr/bin/env python3
"""Pin the Huline village-entry Bacatta (actor57, prop482/group10162) as a source contract and stage the two village
door leaves (movables 56/57, template82) it shuts.

Every record, command group and predicate is read from the hash-checked L4_HJ archive and asserted byte for byte.
Scope:
- region3501 g7026: VILLAGE room 12, then prop482 event20, then the op18 return point;
- prop482 event20 → g10162 under predicate173 (GV_BACATTA_RELATIONSHIP==0);
- region3157 g5570 under predicate167 (GV_MET_BACATTA==1), which removes 57 (and 65, owned by jungle_bacatta65);
- the actor57 placement and the control216 timer row that g10162 starts (unowned alarm, reported only).
Native facts (LOLG.DAT, static; file offset = address + 0x37000):
- op14 (B47B4): byte4 = operation, byte5 = argument, byte6 = nth kind2 record of the owner. Operation3 (B485C) clears
  the record's stopped bit.
- op197 (dispatcher 64770 → 64CD4, jump table 0xBC84 via fixups): sub2 = region[+0x1C] |= 1. The movement tests at
  B0D98/AFF85 treat bit0 as impassable. The village gate sets bits 0|1 when closed and clears bit0 when opened.
- op1 kind32 = movable travel target in percent (same encoding as the village gate's g4354). For leaves 56/57,
  100 swings both about the corners of region3501's west edge until their free ends meet: the double door shuts.
- New-game globals: GLOBAL.MIX key 3984507021, u32(+0x60) bytes at u32(+0x64), read verbatim into the shared table by
  9F0DC. GV_LUTHERS_SOUL=5, GV_DAWN_RELATIONSHIP=1, GV_BACATTA_RELATIONSHIP=1; every other global is 0.
- CAN.WOM exit 0xE09 sets GV_BACATTA_RELATIONSHIP=0 (import 0xFD8 = set global), so g10162 fires on a village
  re-entry after the farewell, not on the first visit.
"""
import hashlib, json, math, shutil, struct, sys
from pathlib import Path
from build_game_atlas import parse_mix, section, u32
from audit_game_actor_scripts import groups
from audit_game_transition_owners import GAME, collect_owners
from prepare_jungle_exit_encounter import predicate
import prepare_jungle_bacatta as B
sys.path.insert(0, '/home/bob/lol2_re_publish_20260911/tools/draracle')
from verify_chain_rotation import model
ROOT = Path(__file__).resolve().parents[1]
MAP = Path('/home/bob/lol2_out/all_maps_20260922/L4_HJ')
ROTATION = Path('/home/bob/lol2_out/draracle_rotation_table_2026-09-11/rotation_table.bin')
OUT = ROOT / 'assets/lol2/generated/jungle_bacatta57'
ACTOR, PROP, THRESHOLD, REMOVAL, CONTROL = 57, 482, 3501, 3157, 216
DOORS = (56, 57)
EXPECTED_GROUPS = {
    (0, 7026): ['0903e4010a00', '0903e5010a00', '0903ad010a00', '0903ac010a00', '091064000a00', '0c03e2010c00', '0903e2011500',
                '120100004af9790f000084005b50000a0000'],
    (1, 10162): ['0e10d80003000100', 'c590ad0d0200', '012038006400', '012039006400', '090239000300'],
    (0, 5570): ['090241000200', '090239000200'],
}
EXPECTED_RECORDS = {  # (owner_kind, owner, kind, value, group): raw record bytes
    ('region', 3501, 2, 0, 7026): '080c721bad0d0200',
    ('prop', 482, 6, 20, 10162): '0606b2271400',
    ('region', 3157, 2, 0, 5570): '080cc215550c0200',
}

def main():
    inventory = json.loads((ROOT / 'docs/game-source-inventory.json').read_text())
    area = next(a for a in inventory['areas'] if a['id'] == 'L4_HJ')
    archive = (GAME / area['source']['file']).read_bytes(); assert hashlib.sha256(archive).hexdigest() == area['source']['sha256']
    entry = next(e for e in parse_mix(archive) if e['key'] == area['source']['geometry_key'])
    raw = archive[entry['offset']:entry['offset'] + entry['size']]; assert hashlib.sha256(raw).hexdigest() == area['source']['geometry_sha256']
    owners, _ = collect_owners(raw, entry['offset'], area['counts']['regions'])
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    parsed = {}
    for stream, (of, sf) in enumerate([(0x3c, 0x84), (0x44, 0x8c)]):
        _, _, blob = section(raw, of, sf, 1)
        for group, commands in groups(blob): parsed[(stream, group)] = [body.hex() for _, body in commands]
    for key, expected in EXPECTED_GROUPS.items(): assert parsed[key] == expected, (key, parsed[key])
    # Completeness: every group naming actor57, prop482, movables56/57 or region3501, and every record owned by
    # actor57/prop482/region3501, is either pinned here or a known other owner (65 removal, the alarm, the 3501 local).
    names = ('023900', '03e201', '203800', '203900', '90ad0d')
    seen = {}
    for o in owners:
        cmds = parsed[(o['stream'], o['group'])]
        mine = any(c[2:8] in names for c in cmds) or (o['owner_kind'], o['owner']) in (('actor', ACTOR), ('prop', PROP), ('region', THRESHOLD))
        if mine: seen[(o['owner_kind'], o['owner'], o['event'], o['value'], o['group'])] = o
    other = {('region', 3501, 2, 0, 7092): 'Left_Village local36 0→2 (room owner)',
             ('control', 216, 2, 304, 27172): 'Huline alarm (unowned): also drives 56/57 to 100'}
    assert set(seen) == set(EXPECTED_RECORDS) | set(other), sorted(set(seen) ^ (set(EXPECTED_RECORDS) | set(other)))
    records = []
    for key in EXPECTED_RECORDS:
        o = seen[key]; n = archive[o['archive_offset']]
        rec = archive[o['archive_offset']:o['archive_offset'] + n].hex()
        if EXPECTED_RECORDS[key]: assert rec == EXPECTED_RECORDS[key], (key, rec)
        records.append(dict(owner_kind=o['owner_kind'], owner=o['owner'], kind=o['event'], value=o['value'], stream=o['stream'], group=o['group'],
                            predicate=o['predicate'], raw=rec, commands=parsed[(o['stream'], o['group'])]))
    predicates = {str(r['predicate']): predicate(table, r['predicate']) for r in records if r['predicate'] is not None}
    assert {k: (p['op'], p['left'], p['right']) for k, p in predicates.items()} == {
        '173': ('==', {'shared': 13}, {'immediate': 0}), '167': ('==', {'shared': 18}, {'immediate': 1})}, predicates
    # control216's kind2 rows in record order; g10162 starts index1 (op14 byte6).
    timer_rows = [archive[o['archive_offset']:o['archive_offset'] + archive[o['archive_offset']]].hex() for o in owners
                  if o['owner_kind'] == 'control' and o['owner'] == CONTROL and o['event'] == 2]
    assert timer_rows == ['0a021a6a300105002c01', '0a02246a300105002c01', '0a02b46a10010502f000'], timer_rows
    alarm = dict(control=CONTROL, record_index=1, raw=timer_rows[1], group=struct.unpack_from('<H', bytes.fromhex(timer_rows[1]), 2)[0],
                 countdown=struct.unpack_from('<H', bytes.fromhex(timer_rows[1]), 8)[0], predicate=192,
                 note='Started by g10162 (op14 operation3). On expiry g27172 runs only when GV_HULINE_ALERT==1 AND local32==0: '
                      'the Huline alarm (gates 78/79 shut, 56/57 to 100, Kelsrick hostile). No port owner; reported, not run.')
    assert alarm['group'] == 27172 and alarm['countdown'] == 300
    # actor57 placement.
    _, _, actors = section(raw, 0x1c, 0x68, 56)
    r = actors[ACTOR * 56:(ACTOR + 1) * 56]; x, z, h, y = struct.unpack_from('<hhHh', r, 0); flags = struct.unpack_from('<H', r, 8)[0]
    actor = dict(id=ACTOR, position=[x, y, -z], heading=h, flags=flags, definition=r[32], health=struct.unpack_from('<H', r, 30)[0], behavior=r[37], byte33=r[33])
    assert (x, z, flags, actor['definition'], actor['health'], actor['behavior'], r[33]) == (-1738, 3974, 0x7182, 5, 200, 4, 0x20), actor
    # op18 (g7026 last command): the player's return point outside the doors.
    op18 = bytes.fromhex(EXPECTED_GROUPS[(0, 7026)][-1])
    return_point = [struct.unpack_from('<h', op18, 4)[0], struct.unpack_from('<h', op18, 8)[0], -struct.unpack_from('<h', op18, 6)[0]]
    assert return_point == [-1718, 0, -3961]
    # Regions.
    geometry = json.loads(B.GEOMETRY.read_text())
    def polygon(index):
        reg = geometry['regions'][index]; assert reg['id'] == index
        return dict(region=index, polygon=[[geometry['vertices_fixed'][v][0] / 65536, -geometry['vertices_fixed'][v][1] / 65536] for v in reg['vertex_indices']],
                    floor_min=min(reg['floor_corners']), floor_max=max(reg['floor_corners']), ceiling=max(reg['ceiling_corners']))
    regions = [polygon(THRESHOLD), polygon(REMOVAL), polygon(3503)]
    assert regions[0]['polygon'] == [[-1624, -4037], [-1565, -4021], [-1613, -3732], [-1729, -3790]]
    def inside(pt, poly):
        c = False
        for i in range(len(poly)):
            (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
            if (y1 > pt[1]) != (y2 > pt[1]) and pt[0] < (x2 - x1) * (pt[1] - y1) / (y2 - y1) + x1: c = not c
        return c
    assert inside((return_point[0], return_point[2]), regions[2]['polygon']) and inside((actor['position'][0], actor['position'][2]), regions[2]['polygon'])
    # Native new-game globals.
    ga = (GAME / 'GLOBAL.MIX').read_bytes(); ge = next(e for e in parse_mix(ga) if e['key'] == 3984507021)
    gblob = ga[ge['offset']:ge['offset'] + ge['size']]
    assert hashlib.sha256(gblob).hexdigest() == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    count, at = u32(gblob, 0x60), u32(gblob, 0x64)
    names = [gblob[at + count + n * 41:at + count + n * 41 + 41].split(b'\0')[0].decode() for n in range(count)]
    initial = {names[n]: gblob[at + n] for n in range(count)}
    assert count == 53 and {k: v for k, v in initial.items() if v} == {'GV_LUTHERS_SOUL': 5, 'GV_DAWN_RELATIONSHIP': 1, 'GV_BACATTA_RELATIONSHIP': 1}
    # Doors: template82 leaves, faces rotated about the native hinge corner with the native rotation table (model()).
    mov = json.loads((MAP / 'movables/movables.json').read_text())
    rotation = ROTATION.read_bytes(); assert hashlib.sha256(rotation).hexdigest() == mov['rotation_table_sha256']
    trig = struct.unpack('<4096i', rotation)
    template = next(t for t in mov['source_templates'] if t['index'] == 82); width, depth, _ = template['dimensions']
    OUT.mkdir(parents=True, exist_ok=True)
    leaves = []
    for index in DOORS:
        placement = next(p for p in mov['placements'] if p['index'] == index)
        d = bytes.fromhex(placement['placement_hex']); mode, travel_half = d[33], d[36]
        assert placement['template'] == 82 and (index, mode, travel_half) in [(56, 1, 45), (57, 4, 47)]
        travel = travel_half * 2 * 65536 // 360
        hx, hy = (width // 2) << 16, (depth // 2) << 16
        corner = [(-hx, hy), (hx, hy), (-hx, -hy), (hx, -hy)][mode // 2]
        pivot = model(corner, tuple(placement['fixed_origin']), placement['heading'], trig)
        faces = [f for f in mov['faces'] if f['placement'] == index]
        assert len(faces) == 41  # 7 children
        frames = []
        for percent in range(101):
            delta = ((-1 if mode & 1 else 1) * (travel * percent // 100)) & 65535
            output = []
            for face in faces:
                vertices = []
                for px, height, negative_y in face['points']:
                    local = (round(px * 65536) - pivot[0], round(-negative_y * 65536) - pivot[1])
                    wx, wy = model(local, pivot, delta, trig)
                    vertices.append([wx / 65536, height, -wy / 65536])
                if percent == 0: assert all(abs(a - b) < 1e-3 for v, q in zip(vertices, face['points']) for a, b in zip(v, q)), (index, vertices, face['points'])
                material = Path(face['material']).parent.name + '.png'
                shutil.copyfile(MAP / face['material'], OUT / material)
                output.append(dict(vertices=vertices, uv=face['uv'], material=material))
            frames.append(output)
        leaves.append(dict(index=index, placement_hex=d.hex(), mode=mode, travel=travel, pivot=[pivot[0] / 65536, 0, -pivot[1] / 65536], frames=frames))
    # Shut pose: the free ends meet on the threshold's west edge.
    def far(leaf, percent):
        pts = [v for f in leaf['frames'][percent] for v in f['vertices'] if v[1] == 0]
        return max(pts, key=lambda v: (v[0] - leaf['pivot'][0]) ** 2 + (v[2] - leaf['pivot'][2]) ** 2)
    a, b = far(leaves[0], 100), far(leaves[1], 100)
    gap = math.hypot(a[0] - b[0], a[2] - b[2]); assert gap < 6, gap
    doors = dict(region=THRESHOLD, leaves=leaves, shut_gap=gap, scope='Source rest faces and the hinge path to target100 (shut). Modern timing and collision; '
                 'native pushing/crushing not replayed.')
    (OUT / 'doors.json').write_text(json.dumps(doors, separators=(',', ':')) + '\n')
    result = dict(version=1, source=area['source'], actor=actor, prop=PROP, control=CONTROL, doors=list(DOORS),
                  threshold=THRESHOLD, removal_region=REMOVAL, regions=regions, records=records, predicates=predicates,
                  alarm=alarm, return_point=return_point, native_initial=initial,
                  shared_names={'13': 'GV_BACATTA_RELATIONSHIP', '18': 'GV_MET_BACATTA'},
                  doors_sha256=hashlib.sha256((OUT / 'doors.json').read_bytes()).hexdigest())
    # Body owner: Bacatta61's BACL4 definition5 row placed as actor57; sprites shared with the Bacatta65 media.
    template_pop = json.loads((ROOT / 'scripts/lol2/jungle_bacatta_population_source.json').read_text())
    assert template_pop['source'] == area['source'] and list(template_pop['definitions']) == ['5']
    body = dict(template_pop['actors'][0], actor=ACTOR, position=actor['position'], heading=actor['heading'], health=actor['health'],
                behavior=actor['behavior'], flags=actor['flags'], present=False)
    population = dict(template_pop, actors=[body], scripted_dormant=[ACTOR],
                      note='actor57 body (BACL4 definition5, as Bacatta61): non-hostile when linked by g10162; hostile once struck; death/corpse use the idle frame.')
    (ROOT / 'scripts/lol2/jungle_bacatta57_population_source.json').write_text(json.dumps(population, indent=1) + '\n')
    (ROOT / 'scripts/lol2/jungle_bacatta57_source.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS actor57/prop482 source: {len(records)} records, predicates {sorted(predicates)}, alarm timer {alarm["group"]}, '
          f'doors 56/57 101 poses each (shut gap {gap:.2f}), native initial globals {[k for k, v in initial.items() if v]}')

if __name__ == '__main__':
    main()
