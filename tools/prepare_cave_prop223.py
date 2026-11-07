#!/usr/bin/env python3
"""Pin the L1_DC prop223 explosion source (groups 2326/2732) beside the scenic prop574 queues.

Prop223 is a template68 helper (selector0 descriptor615 = external explode.vqa, fallback selector1 = prop_617), placed
absent (placement flags 0x5402: bit 0x1000). Stream0 group560 (region969, predicate9 local0==0) links it (op9
property3) while unlinking guard55 and prop574. Records, in source order:
  kind9 0a091609110000000283 at predicate2 (owner state0): masks 0x0011/0x0000, threshold2, mode0x83 -> group2326.
  kind6 value0 (prop223's own movie end): group2732.
Group2326 is group5926 (prop574) except: op15 burst on prop223 itself (5926: object 222); no op9 property21 on
prop1031 (magic reward); no second op20 (sound 426); no actor55 op13 commands; op6 sub1 and op8 0/2 on prop223.
Group2732: op8 1, op6 2, op16 state1, op9 property2 (unlink) on prop223.
Writes the groups in the scenic source command format. Usage: prepare_cave_prop223.py --output PATH
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section

MAP = Path('~/lol2_out/all_maps_20260922/L1_DC')
GROUPS = [(1, 2326), (1, 2732)]


def group(owners, streams, stream, g):
    handlers = [o for o in owners if o['stream'] == stream and o['group'] == g]
    commands = []
    for c in streams[stream][g]:
        c = dict(c); b = bytes.fromhex(c['raw_hex'])
        c.update(op=b[0], kind=b[1], target=struct.unpack_from('<H', b, 2)[0])
        if len(b) >= 6: c.update(argument=b[4], value=b[5])
        commands.append(c)
    return dict(stream=stream, handlers=handlers, commands=commands)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--scenic-source', type=Path, required=True, help='scripts/lol2/cave_scenic_guard_source.json (groups 5926/6364/560)')
    a = p.parse_args()
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    area, archive, ge, geo, owners, streams = source_area('L1_DC')
    scenic = json.loads(a.scenic_source.read_text())
    groups = {str(g): group(owners, streams, s, g) for s, g in GROUPS}
    raw = lambda gid, src=groups: [c['raw_hex'] for c in src[gid]['commands']]
    # Handlers: prop223 kind9 (predicate2) and kind6 value0, nothing else owns these groups.
    h9, = groups['2326']['handlers']; h6, = groups['2732']['handlers']
    assert (h9['owner_kind'], h9['owner'], h9['event'], h9['predicate']) == ('prop', 223, 9, 2), h9
    assert (h6['owner_kind'], h6['owner'], h6['event'], h6['value'], h6['predicate']) == ('prop', 223, 6, 0, None), h6
    hit = archive[h9['archive_offset']:][:10]
    assert hit.hex() == '0a091609110000000283'
    assert [o for o in owners if o['owner_kind'] == 'prop' and o['owner'] == 223] == [h9, h6]
    _, _, predicates = section(geo, 0xbc, 0xb8, 5)
    assert predicates[2 * 5:3 * 5].hex() == '0005000000'  # owner state == 0
    # Exact relation to the hosted prop574 groups (scenic source, pinned there from the same archive).
    s5926 = raw('5926', scenic['groups']); s6364 = raw('6364', scenic['groups'])
    assert raw('2326')[0] == '0f03df006503df00' and s5926[0] == '0f033e026503de00'
    removed = ['090307041500', '14034502aa01fa011907', '06033e020100', '08033e0200000000', '08033e0202000000',
               '0d02370006040000', '0d02370004030000']
    added = ['0603df000100', '0803df0000000000', '0803df0002000000']
    assert [c for c in s5926[1:] if c not in removed] == [c for c in raw('2326')[1:] if c not in added], 'g2326 != g5926 - removed + added'
    assert all(c in s5926 for c in removed) and all(raw('2326').count(c) == 1 for c in added)
    assert raw('2326')[-1] == 'c60000000001' and '140345029b01fa011907' in raw('2326')
    assert raw('2732') == ['0803df0001000000', '0603df000200', '1003df000100', '0903df000200']
    assert s6364[:4] == ['08033e0201000000', '06033e020200', '10033e020100', '09033e020200'] and s6364[4] == '100237000100'
    s560 = raw('560', scenic['groups'])
    assert s560[:4] == ['090236000300', '0903df000300', '090237000200', '09033e020200']
    catalog = json.loads((MAP / 'props/props.json').read_text())
    row = next(r for r in catalog['props'] if r['record'] == 223)
    placement = archive[row['placement_offset']:row['placement_offset'] + 37]
    assert placement.hex() == row['placement_hex'] and row['template'] == 68 and row['fallback_chain'] == [0, 1]
    flags = struct.unpack_from('<H', placement, 8)[0]
    assert flags == 0x5402 and placement[30] == 3, (hex(flags), placement[30])
    movie = next(r for r in catalog['video_references'] if r['record'] == 223)
    assert movie['descriptor'] == 615 and 'explode.vqa' in movie['reason']
    t68 = next(r for r in catalog['video_references'] if r['record'] == 574)
    assert t68['descriptor'] == 615 and t68['template'] == movie['template'] == 68
    result = dict(version=1, source=dict(area='L1_DC', archive_sha256=hashlib.sha256(archive).hexdigest()),
                  prop=223, position=row['position'], region=row['region'], placement_hex=placement.hex(),
                  flags=flags, absent=bool(flags & 0x1000), durability=placement[30], hit_record_hex=hit.hex(),
                  masks=[0x0011, 0x0000], threshold=2, mode=0x83, movie='EXPLODE.VQA', movie_descriptor=615,
                  burst_object=223, prop574_burst_object=222, groups=groups,
                  differences_from_5926=dict(removed=removed, added=added, first='0f03df006503df00 replaces 0f033e026503de00'),
                  scope='Source groups and admission record for prop223; the hit/queue rules are in the release native receipt.')
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS prop223 source: groups 2326 (%d) and 2732 (%d), hit %s, absent placement, explode.vqa' %
          (len(groups['2326']['commands']), len(groups['2732']['commands']), hit.hex()))


if __name__ == '__main__':
    main()
