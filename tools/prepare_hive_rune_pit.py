#!/usr/bin/env python3
"""Stage scripts/lol2/hive_rune_pit_source.json: the Hive rune-pit floor tiles and their RUNES room entry groups.

  python3 tools/prepare_hive_rune_pit.py --game GAME [--output scripts/lol2/hive_rune_pit_source.json]

Source (pinned original L5_HC): region 506 (floor -1709, the room below the corridor region679 at -1659) owns 169 floor
subdivisions. 105 of them carry one descriptor kind12 region record, event1 value1, whose stream0 group runs the same
room sequence as control0's kind4 group5244: [opcode197 sub10 marker642] [opcode9 prop71 property21 (Dawn20 link)]
opcode12 room 11 ("runes_" in the executable room-name table) and opcode18 reposition to (-3113, 6282) flags 0x0885
bearing 8192. 99 tiles carry all four commands, five omit opcode197, and region625 selects room 10 ("runecl_")
without opcode197/opcode9. The tile polygons, floors, commands and pose are re-derived here; nothing is executed.
"""
import argparse, hashlib, json, struct, sys, tempfile
from pathlib import Path

ARCHIVE_SHA = 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
GEOMETRY_KEY = 3776990464
OWNER = 506
FULL = ['c59082020a00', '090347001500', '0c0371010b00', '12010000d7f38a1800008508002000000000']


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output', type=Path, default=Path('scripts/lol2/hive_rune_pit_source.json'))
    a = p.parse_args()
    archive = (a.game / 'DAT/L5_HC.MIX').read_bytes()
    if hashlib.sha256(archive).hexdigest() != ARCHIVE_SHA: p.error('L5_HC.MIX is not the pinned original')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    from build_game_atlas import parse_mix, section
    from audit_game_transition_owners import events
    from audit_game_actor_scripts import groups
    import map_geometry
    entry = next(e for e in parse_mix(archive) if e['key'] == GEOMETRY_KEY)
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    _, _, stream0 = section(raw, 0x3c, 0x84, 1); group_rows = dict(groups(stream0))
    _, _, region_events = section(raw, 0x38, 0x80, 1)
    _, desc_count, descriptors = section(raw, 0xa4, 0xac, 26)
    with tempfile.TemporaryDirectory(prefix='hive-rune-pit-') as tmp:
        map_geometry.export_geometry(a.game, 'L5_HC', Path(tmp) / 'geometry')
        geometry = json.loads((Path(tmp) / 'geometry/geometry.json').read_text())
    assert geometry['source']['sha256'] == ARCHIVE_SHA, 'geometry source'
    vertices, regions = geometry['vertices_fixed'], geometry['regions']
    subdivisions = set(regions[OWNER]['floor_subdivisions'])
    assert regions[OWNER]['floor_corners'] == [-1709] * 4 and len(subdivisions) == 169, 'region506 pit owner'
    assert regions[679]['floor_corners'] == [-1659] * 4 and OWNER in regions[679]['neighbors'], 'corridor region679'
    tiles, offsets = [], sorted({struct.unpack_from('<H', descriptors, i * 26 + 10)[0] for i in range(desc_count)})
    for offset in offsets:
        for _, kind, body, predicate in events(region_events, offset):
            if kind != 12 or len(body) < 8: continue
            group, region, event, value = struct.unpack_from('<HHBB', body, 2)
            if region not in subdivisions: continue
            assert (event, value, predicate) == (1, 1, None), ('pit record', region, body.hex())
            commands = [c.hex() for _, c in group_rows[group]]
            reposition = bytes.fromhex(commands[-1]); assert reposition[0] == 18
            x, y, z = struct.unpack_from('<hhh', reposition, 4); flags, bearing = struct.unpack_from('<HH', reposition, 10)
            assert (x, y, z, flags, bearing) == (-3113, 6282, 0, 0x0885, 8192), ('pit reposition', region)
            room = [c for c in commands if c.startswith('0c03')]; assert len(room) == 1
            r = regions[region]
            tiles.append(dict(region=region, group=group, event=event, value=value, floor=r['floor_corners'][0],
                              polygon=[[vertices[v][0] / 65536, -vertices[v][1] / 65536] for v in r['vertex_indices']],
                              commands=commands, marker642=commands[0] == FULL[0], dawn20_link=FULL[1] in commands,
                              room_index=struct.unpack_from('<H', bytes.fromhex(room[0]), 4)[0]))
    assert len(tiles) == 105 and len({t['region'] for t in tiles}) == 105, len(tiles)
    assert sum(t['commands'] == FULL for t in tiles) == 99
    assert [t['region'] for t in tiles if t['room_index'] == 10] == [625]
    assert all(t['room_index'] == 11 for t in tiles if t['region'] != 625)
    source = dict(version=1, archive_sha256=ARCHIVE_SHA, owner_region=OWNER, corridor_region=679,
                  room_names={'10': 'RUNECL', '11': 'RUNES'},
                  return_pose=dict(xz=[-3113, -6282], bearing=8192, flags=0x0885, support_region=679, support_floor=-1659),
                  tiles=sorted(tiles, key=lambda t: t['region']),
                  scope='Region kind12 event1 value1 records of the region506 floor subdivisions and their stream0 groups. '
                        'Hosting a grounded arrival on a tile as event1 is the port adapter, matched to the original longplay '
                        '(walking into the pit opens the RUNES room); native event1 dispatch is not replayed.')
    a.output.write_text(json.dumps(source, indent=1) + '\n')
    print('PASS hive_rune_pit:', len(tiles), 'tiles;', sum(t['marker642'] for t in tiles), 'with opcode197;',
          'room10 tiles', [t['region'] for t in tiles if t['room_index'] == 10], '->', a.output)


if __name__ == '__main__':
    main()
