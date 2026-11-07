#!/usr/bin/env python3
"""Stage the two Dark Halls (L7_DH) doors (movables 56/57, template16 "Door") and door 57's Shade trap.

Source (verify_actor_item_grants.source_area L7_DH, predicates from the 0xbc table):
  movable56/57 kind4 (use) state0: op1 -> 100 (open), state 1; state1: op1 -> 0, state 0 (E toggles).
  movable57 kind4 state2 (locked): sound 883 then state3 (no travel and no state3 use row). region1338 kind4 g794: op20 slam sound, op1 movable57 -> 0, state 2,
      op18 actor73 (a grid SHADE) to (-1895, 1700) heading 32768, op13 sub12/sub7 (wake). actor73 kind6 value10 g15750:
      op16 movable57 state 0 (unlocked). Kind9 selector stages end with a percent100 request, not a state3 write; hit-filter producer not replayed.
Motion (as prepare_jungle_inner_gate.py): placement byte33 = hinge corner/direction (mode), byte34 = 6 (hinge),
byte36 = half the swing in degrees (travel = 2 * byte36 degrees), the hinge at template corner mode//2 rotated by the
placement heading about fixed_origin; positive native angle turns the map clockwise (Godot rotation -angle).
Modern adapters (docs/DEVIATIONS.md): swing time 1 s, E within reach, collision box per leaf (native template box),
actor73's wake = moved next to the trap and hunting; door bashing and the region83 door56 lock are not hosted.
Usage: prepare_dark_halls_doors.py --game GAME --movables L7_MOVABLES_JSON [--project PROJECT]
"""
import argparse, json, math, struct
from pathlib import Path
from verify_actor_item_grants import source_area
from prepare_jungle_exit_encounter import predicate
from build_game_atlas import section
import prepare_dark_halls_routes as Routes

ROOT = Path(__file__).resolve().parents[1]
DOORS = (56, 57)
TRAP_REGION, TRAP_ACTOR = 1338, 73


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--movables', type=Path, required=True)
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    game = a.game.resolve()
    _, _, _, raw, owners, streams = source_area('L7_DH', game)
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    def cmds(o): return [c['raw_hex'] for c in streams[o['stream']][o['group']]]
    def rows(kind, owner, event): return [o for o in owners if o['owner_kind'] == kind and o['owner'] == owner and o['event'] == event]
    mov = json.loads(a.movables.read_text())
    templates = {t['index']: t for t in mov['source_templates']}
    area = json.loads((a.project / 'assets/lol2/generated/dark_halls/area.json').read_text())
    doors = []
    for index in DOORS:
        uses = {predicate(table, o['predicate'])['right']['immediate']: cmds(o) for o in rows('movable', index, 4)}
        assert uses[0] == [f'0120{index:02x}006400', f'1020{index:02x}000100'] and uses[1] == [f'0120{index:02x}000000', f'1020{index:02x}000000'], uses
        pl = next(x for x in mov['placements'] if x['index'] == index)
        d = bytes.fromhex(pl['placement_hex']); mode, kind, half = d[33], d[34], d[36]
        assert pl['template'] == 16 and kind == 6, (index, pl['template'], kind)
        width, depth, height = templates[16]['dimensions']
        hx, hy = width / 2, depth / 2
        cx, cy = [(-hx, hy), (hx, hy), (-hx, -hy), (hx, -hy)][mode // 2]
        ang = pl['heading'] / 65536 * math.tau
        s, c = math.sin(ang), math.cos(ang)
        ox, oy = pl['fixed_origin'][0] / 65536, pl['fixed_origin'][1] / 65536
        pivot = (ox + cx * c + cy * s, oy + cy * c - cx * s)  # verify_chain_rotation.model in floats
        faces = [f for f in area['faces'] if f.get('kind') == 'movable' and f.get('placement_kind') == 'movable' and f['source_index'] == index]
        assert len(faces) == 20, (index, len(faces))
        doors.append(dict(movable=index, mode=mode, swing_degrees=2 * half, sign=-1 if mode & 1 else 1, heading=pl['heading'],
                          origin=[ox, pl['height'], -oy], pivot=[pivot[0], pl['height'], -pivot[1]], size=[width, height, max(depth, 4)],
                          use_open=uses[0], use_close=uses[1], speed_byte=d[37]))
    trap = [o for o in rows('region', TRAP_REGION, 4)]
    assert len(trap) == 1
    trap_cmds = cmds(trap[0])
    assert trap_cmds[1:3] == ['012039000000', '102039000200'] and trap_cmds[3].startswith('12024900'), trap_cmds
    move = bytes.fromhex(trap_cmds[3]); tx, ty = struct.unpack_from('<hh', move, 4); heading = struct.unpack_from('<H', move, 12)[0]
    unlock = [o for o in rows('actor', TRAP_ACTOR, 6) if o['value'] == 10 and cmds(o) == ['102039000000']]
    assert len(unlock) == 1
    locked = [o for o in rows('movable', 57, 4) if predicate(table, o['predicate'])['right']['immediate'] == 2]
    assert len(locked) == 1 and cmds(locked[0])[1] == '102039000300', cmds(locked[0])
    hive = Routes.Hive.load(game, 'dark_halls')
    from lol2_geometry_format import slope_corners
    rec = hive['records'][TRAP_REGION]
    polygon = [[hive['vertices'][v][0] / 65536, -hive['vertices'][v][1] / 65536] for v in rec[6:10]]
    result = dict(version=1, archive='DAT/L7_DH.MIX', doors=doors,
                  trap=dict(region=TRAP_REGION, group=trap[0]['group'], commands=trap_cmds, polygon=polygon,
                            floor=min(slope_corners(hive['records'], TRAP_REGION)), door=57, actor=str(TRAP_ACTOR),
                            actor_to=[tx, -ty], actor_heading=heading, unlock_group=unlock[0]['group'],
                            locked_use=cmds(locked[0])),
                  not_hosted=['kind9 hit sequence: selectors 1/2/3; group13798 requests percent100 (hit-filter producer not replayed)', 'region83 g76 (local6 == 0 AND local4 == 1): door56 shut, state 3',
                              'door57 locked use: sound 883 then state 3 without travel; no state3 use row; actor73 event6/value10 group15750 resets state0'],
                  scope='Doors 56/57 E toggle and native hinge; door57 Shade trap (region1338) and its actor73 unlock. Swing time, reach and leaf box are modern adapters.')
    (a.project / 'scripts/lol2/dark_halls_doors_source.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS Dark Halls doors: {[(d["movable"], d["mode"], d["swing_degrees"], [round(v) for v in d["pivot"]]) for d in doors]}; '
          f'trap region {TRAP_REGION} -> door57 locked, actor73 to {(tx, -ty)}, unlock g{unlock[0]["group"]}')


if __name__ == '__main__':
    main()
