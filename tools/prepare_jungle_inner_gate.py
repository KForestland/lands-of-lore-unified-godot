#!/usr/bin/env python3
"""Pin Kelsrick's inner village gate (movables 74/75, template43) as a source contract and stage its hinge poses.

The double gate lies on region2750 (behind Kelsrick's region3567). At travel 0 the two leaves meet across that line
(shut); 100 swings them south (open).
Source producers (every record naming movables 74/75 is pinned or attributed):
- region2752 g5160 (far side, any entry): both → 100;
- control98 kind3 value0 g21138 (both → 0) and value1 g21156 (both → 100). The selector ends of the invisible logic
  control98, played by Kelsrick's g5084 (selector0) and g30684 (talk1 end, selector1);
- movable74/75 kind4 mode0 (plain use) under predicate191 GV_KELSRICK_DEAD==1: g27916 opens 74 only (its two commands
  both name 74), g27934 opens both;
- Kelsrick region2750 g5084 (local6==0) and the village alarm g27172: both → 0 (run by those owners);
- g4442 (region2443, p111) and prop561 g14086: no port owner; attributed and reported.
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
OUT = ROOT / 'assets/lol2/generated/jungle_inner_gate'
LEAVES = (74, 75)
OWNED = {('region', 2752, 2, 0, 5160): ['01204a006400', '01204b006400'],
         ('control', 98, 3, 0, 21138): ['01204b000000', '01204a000000'],
         ('control', 98, 3, 1, 21156): ['01204b006400', '01204a006400'],
         ('movable', 74, 4, 0, 27916): ['01204a006400', '01204a006400'],
         ('movable', 75, 4, 0, 27934): ['01204a006400', '01204b006400']}
OTHER = {('region', 2750, 2, 0, 5084): 'Kelsrick owner (talk2 region; local6==0): 74/75 → 0 and op5 control98 selector0, emitted through its effects hook',
         ('control', 216, 2, 304, 27172): 'village alarm: 74/75 → 0',
         ('region', 2443, 2, 0, 4442): 'unowned (village gate branch p111 alert==0 AND local6==1); reported',
         ('prop', 561, 6, 2, 14086): 'unowned (prop561 event2); reported'}

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
    by_key = {(o['owner_kind'], o['owner'], o['event'], o['value'], o['group']): o for o in owners}
    # Completeness: every record whose group names movable74/75, or owned by them.
    seen = {k for k, o in by_key.items() if any(c[2:8] in ('204a00', '204b00') for c in parsed[(o['stream'], o['group'])]) or (k[0], k[1]) in (('movable', 74), ('movable', 75))}
    assert seen == set(OWNED) | set(OTHER), sorted(seen ^ (set(OWNED) | set(OTHER)))
    records = []
    for key, commands in OWNED.items():
        o = by_key[key]; assert parsed[(o['stream'], key[4])] == commands, (key, parsed[(o['stream'], key[4])])
        n = archive[o['archive_offset']]; rec = archive[o['archive_offset']:o['archive_offset'] + n]
        if key[2] == 4: assert rec[4] == 0, rec.hex()  # kind4 mode0: plain use
        records.append(dict(owner_kind=key[0], owner=key[1], kind=key[2], value=key[3], group=key[4], predicate=o['predicate'], raw=rec.hex(), commands=commands))
    predicates = {str(r['predicate']): predicate(table, r['predicate']) for r in records if r['predicate'] is not None}
    assert {k: (p['op'], p['left'], p['right']) for k, p in predicates.items()} == {'191': ('==', {'shared': 11}, {'immediate': 1})}
    geometry = json.loads(B.GEOMETRY.read_text())
    def region(index):
        reg = geometry['regions'][index]; assert reg['id'] == index
        return dict(region=index, polygon=[[geometry['vertices_fixed'][v][0] / 65536, -geometry['vertices_fixed'][v][1] / 65536] for v in reg['vertex_indices']],
                    floor_min=min(reg['floor_corners']), floor_max=max(reg['floor_corners']))
    regions = [region(2752), region(2750)]
    # Leaves: source rest faces rotated about the native hinge corner with the native rotation table.
    mov = json.loads((MAP / 'movables/movables.json').read_text())
    rotation = ROTATION.read_bytes(); assert hashlib.sha256(rotation).hexdigest() == mov['rotation_table_sha256']
    trig = struct.unpack('<4096i', rotation)
    OUT.mkdir(parents=True, exist_ok=True)
    leaves = []
    for index in LEAVES:
        placement = next(p for p in mov['placements'] if p['index'] == index)
        template = next(t for t in mov['source_templates'] if t['index'] == placement['template'])
        width, depth, _ = template['dimensions']
        d = bytes.fromhex(placement['placement_hex']); mode, half = d[33], d[36]
        assert placement['template'] == 43 and (index, mode) in [(74, 4), (75, 1)]
        travel = half * 2 * 65536 // 360
        hx, hy = (width // 2) << 16, (depth // 2) << 16
        corner = [(-hx, hy), (hx, hy), (-hx, -hy), (hx, -hy)][mode // 2]
        pivot = model(corner, tuple(placement['fixed_origin']), placement['heading'], trig)
        faces = [f for f in mov['faces'] if f['placement'] == index]
        frames = []
        for percent in range(101):
            delta = ((-1 if mode & 1 else 1) * (travel * percent // 100)) & 65535
            output = []
            for face in faces:
                vertices = []
                for px, height, negative_y in face['points']:
                    wx, wy = model((round(px * 65536) - pivot[0], round(-negative_y * 65536) - pivot[1]), pivot, delta, trig)
                    vertices.append([wx / 65536, height, -wy / 65536])
                if percent == 0: assert all(abs(a - b) < 1e-3 for v, q in zip(vertices, face['points']) for a, b in zip(v, q))
                material = Path(face['material']).parent.name + '.png'
                shutil.copyfile(MAP / face['material'], OUT / material)
                output.append(dict(vertices=vertices, uv=face['uv'], material=material))
            frames.append(output)
        leaves.append(dict(index=index, mode=mode, travel=travel, pivot=[pivot[0] / 65536, 0, -pivot[1] / 65536], frames=frames, faces=len(faces)))
    def far(leaf, percent):
        pts = [v for f in leaf['frames'][percent] for v in f['vertices']]
        return max(pts, key=lambda v: (v[0] - leaf['pivot'][0]) ** 2 + (v[2] - leaf['pivot'][2]) ** 2)
    a, b = far(leaves[0], 0), far(leaves[1], 0)
    gap = math.hypot(a[0] - b[0], a[2] - b[2]); assert gap < 6, gap  # shut at rest
    (OUT / 'leaves.json').write_text(json.dumps(dict(leaves=leaves, shut_gap=gap), separators=(',', ':')) + '\n')
    result = dict(version=1, source=area['source'], leaves=list(LEAVES), records=records, predicates=predicates, regions=regions,
                  other_records={f'{k[0]}{k[1]}/{k[2]}/{k[3]}/g{k[4]}': v for k, v in OTHER.items()},
                  leaves_sha256=hashlib.sha256((OUT / 'leaves.json').read_bytes()).hexdigest())
    (ROOT / 'scripts/lol2/jungle_inner_gate_source.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS inner gate 74/75: {len(records)} records, rest shut gap {gap:.2f}, faces {[l["faces"] for l in leaves]}')

if __name__ == '__main__':
    main()
