#!/usr/bin/env python3
"""Pin the L1_DC shrine doorway blocks (static assemblies / controls 0 and 1; owner report 2026-10-20 18:53, "should
be able to move them") from the original archive and executable.

Source (L1_DC): two template43 carved-stone blocks (materials 962/963, wood 16) at native (-442, 10758) and
(-512, 10759), 50 x 97 x 50, standing in the corridor (region1952, x -544..-407). Gaps 7/20/10 units: nobody passes.
Each control has exactly one record, kind10 (contact), raw 080a<group>06022600:
  byte4 = 6, byte5 = 2, word6 = 38. Contact walker AE7D8 (callers 5BA99/5BAB0 and B22B0/B22C7 dispatch each
  colliding object's list with the other object; B1CC9 with none) switches on byte4-2 through the table at AE7C4;
  case 6 (AE851) matches when 5FBC8(byte5, word6) is the other object. 5FBC8 kind2 = the actor pool, so the record
  fires when actor38 (the colonnade guard) touches the block. The player (kind1, 0x22574) never matches.
  control0 g9666 / control1 g9708: two op18 on the controls (flags 0x0012, byte15 10, bit 0x20 clear: no queued
  command) move both blocks sideways into the corridor niches (regions 1949-1951/1953): control0 to x -393/-396,
  control1 to x -565/-561.
Actor38 starts unlinked at (-532, 10347) north of the shrine; region1941 g2328 (player entry, south of the colonnade)
links him. He chases south, meets the blocks and they part (longplay 9:05 closed, 9:35 open in the niches).
Usage: prepare_cave_shrine_doors.py --output scripts/lol2/cave_shrine_doors_source.json [--game GAME]
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area, GAME

ROOT = Path(__file__).resolve().parents[1]
CONTROLS = {0: (9666, '080ac22506022600', ['12100100cbfd082a000012000000000a0000', '1210000077fe082a000012000000000a0000']),
            1: (9708, '080aec2506022600', ['1210000074fe092a000012000000000a0000', '12100100cffd022a000012000000000a0000'])}
PLACEMENTS = {0: '46fe062a000024ff8205a00744171883000000000100000000000000140074002b',
              1: '00fe072a000024ff8205a0074e171883000000000100000000000000140074002b'}
GUARD = 38
# AE7D8 kind10 contact walker: byte4 switch (byte4-2, 5 cases) through the table at AE7C4 (raw + 0x59024).
WALKER = {'table': 0xae7c4, 'cases': [0xae812, 0xae81c, 0xae823, 0xae82b, 0xae851],
          'callers': [0x5ba99, 0x5bab0, 0xb1cc9, 0xb22b0, 0xb22c7]}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--game', type=Path, default=None)
    a = p.parse_args()
    game = a.game.resolve() if a.game else GAME
    area, arc, entry, raw, owners, streams = source_area('L1_DC', game)
    exe = (game / 'LOLG.DAT').read_bytes()
    file = lambda addr: addr + 0x37000
    # Native contact walker: switch table, case6 body and every caller.
    assert [struct.unpack_from('<I', exe, file(WALKER['table']) + 4 * i)[0] + 0x59024 for i in range(5)] == WALKER['cases']
    # Case6: push word6, push byte5, call 5FBC8, compare with the other object (esi).
    assert exe[file(0xae851):file(0xae851) + 21].hex() == '31c0668b43065031c08a430550e865' '13fbff83c408'
    found = sorted(o - 0x37000 for o in range(0x37000, len(exe) - 5)
                   if exe[o] == 0xe8 and (o - 0x37000 + 5 + struct.unpack_from('<i', exe, o + 1)[0]) & 0xffffffff == 0xae7d8)
    assert found == WALKER['callers'], [hex(x) for x in found]
    # 5FBC8: kind1 -> player 0x22574, kind2 -> actor pool [0x9696c].
    assert exe[file(0x5fc12):file(0x5fc12) + 5].hex() == 'b874250200'
    assert exe[file(0x5fc1c):file(0x5fc1c) + 6].hex() == '8b356c690900'
    poses = {}
    for control, (group, record, commands) in CONTROLS.items():
        mine = [o for o in owners if o['owner_kind'] == 'control' and o['owner'] == control]
        assert len(mine) == 1 and mine[0]['event'] == 10 and mine[0]['group'] == group and mine[0]['predicate'] is None, mine
        r = arc[mine[0]['archive_offset']:mine[0]['archive_offset'] + arc[mine[0]['archive_offset']]]
        assert r.hex() == record, r.hex()
        assert r[4] == 6 and r[5] == 2 and struct.unpack_from('<H', r, 6)[0] == GUARD
        assert [c['raw_hex'] for c in streams[1][group]] == commands
        for c in commands:
            b = bytes.fromhex(c)
            assert b[0] == 0x12 and b[1] == 0x10 and struct.unpack_from('<H', b, 10)[0] == 0x12 and b[15] == 10
            target = struct.unpack_from('<H', b, 2)[0]
            poses.setdefault(str(group), {})[str(target)] = dict(x=struct.unpack_from('<h', b, 4)[0], y=struct.unpack_from('<h', b, 6)[0],
                                                                 heading=struct.unpack_from('<H', b, 12)[0], raw=c)
    placements = {}
    for control, hexed in PLACEMENTS.items():
        offset = arc.find(bytes.fromhex(hexed))
        assert offset > 0 and arc.find(bytes.fromhex(hexed), offset + 1) < 0
        b = bytes.fromhex(hexed)
        placements[str(control)] = dict(offset=offset, hex=hexed, x=struct.unpack_from('<h', b, 0)[0], y=struct.unpack_from('<h', b, 2)[0])
    # Actor38: unlinked at start (flags bit 0x1000), linked by region1941 g2328.
    _, _, actors = __import__('build_game_atlas').section(raw, 0x1c, 0x68, 56)
    g = actors[GUARD * 56:(GUARD + 1) * 56]
    assert struct.unpack_from('<H', g, 8)[0] & 0x1000
    spawn = [o for o in owners if o['owner_kind'] == 'region' and o['owner'] == 1941 and o['group'] == 2328]
    assert len(spawn) == 1 and '090226000300' in [c['raw_hex'] for c in streams[0][2328]]
    contract = {
        'version': 1, 'source': {'area': 'L1_DC', 'archive_sha256': hashlib.sha256(arc).hexdigest(),
                                 'executable_sha256': hashlib.sha256(exe).hexdigest()},
        'controls': {str(c): {'group': g_, 'record': rec, 'commands': cmds} for c, (g_, rec, cmds) in CONTROLS.items()},
        'placements': placements, 'poses': poses, 'guard': GUARD,
        'walker': {'entry': '0xae7d8', 'case6': '0xae851', 'callers': [hex(x) for x in WALKER['callers']],
                   'lookup': '0x5fbc8 kind2 = actor pool, kind1 = player'},
        'adapters': ['contact = guard38 capsule within its radius + 2 of a block box (the native collision pair is the '
                     'physics contact; the guard is stopped by the solid block first)',
                     'op18 flags 0x12 / byte15 10 travel is not replayed: both blocks slide linearly to the group\'s '
                     'targets in SLIDE_SECONDS; the first contact wins (controls 0 and 1 run identical moves)'],
        'not_hosted': ['op18 heading word (0) and the per-group 3-4 unit target differences beyond the first group'],
    }
    a.output.write_text(json.dumps(contract, indent=1) + '\n')
    print('PASS cave shrine doors: controls 0/1 kind10 contact with actor38 -> op18 slide;', poses)


if __name__ == '__main__':
    main()
