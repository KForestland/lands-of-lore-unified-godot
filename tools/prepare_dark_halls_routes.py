#!/usr/bin/env python3
"""Prepare the original Jungle pocket <-> Dark Halls (L7_DH) route records (copy of the Hive route recipe).

Source facts (checked here):
  - MCEL_.WOM hotspot 1 (164,177)-(237,295), registered unconditionally at setup 0x4A8, click 0x658: host 0xA30
    (5618, -2369) then exit_room. That point is in L4 region 3191 of the isolated pocket (regions 3190-3233).
  - L4 region 3205, event 4, group 6292: level change 020100001c27 -> level 7 entry 1.
  - L7 regions 1394, 1408-1413, event 2: level change -> level 4 entry 6 (the same group also sets
    GV_DARK_HALLS_OPEN; not hosted yet).
Admission is the existing grounded-polygon adapter of hive_route.gd; the native crossed-region dispatcher is not
reproduced. Usage: prepare_dark_halls_routes.py --game GAME --output-root FRESH_DIR
"""
import argparse, json, struct
from pathlib import Path
import prepare_hive_routes_data as Hive
from lol2_geometry_format import slope_corners

Hive.SOURCES['dark_halls'] = ('L7_DH', 3374994708, '40b394ebb3cfcfd9f332c4707f2f9e9e7de76d89b82836cec211772ca456b8e7')
CELLAR = dict(room='MCEL', hotspot=1, rect=[164, 177, 237, 295], native=[5618, -2369], region=3191)
LINKS = [('jungle', 3205, 4, 1, 'dark_halls')] + [('dark_halls', r, 2, 6, 'jungle') for r in (1394, 1408, 1409, 1410, 1411, 1412, 1413)]
LEVEL = {'jungle': 4, 'dark_halls': 7}
# Workaround (docs/DEVIATIONS.md): the seven exit regions (floor 700) form a floor island no walkable region reaches;
# the original opens them by a scripted event (broken wall / sphere-room floor, not hosted). Region 1598 (floor 760,
# 42 units from exit 1394) is the walkable spot at that wall; it takes exit 1394's route until the event is hosted.
SLICE_EXITS = [((1598, 1617), 1394)]  # 1598 is a 10-unit sliver along the wall; hull with its floor-760 neighbour 1617


def hull(points):
    """Convex hull (monotone chain), counter-clockwise."""
    pts = sorted(set(points))
    def cross(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def prepare(game, output):
    Hive.require(not output.exists(), 'Output must be a fresh directory')
    sources = {name: Hive.load(game, name) for name in ('jungle', 'dark_halls')}
    routes = {'jungle': [], 'dark_halls': []}
    for area, region, event, entry, destination in LINKS:
        source, dest = sources[area], sources[destination]
        owners = [o for o in source['owners'] if o['owner_kind'] == 'region' and o['owner'] == region and o['event'] == event]
        Hive.require(len(owners) == 1, f'Expected one route event owner for {area} region {region}')
        owner = owners[0]
        rows = [(offset, b) for offset, b in source['groups'][owner['group']] if b[:5] == bytes.fromhex('020100001c')]
        Hive.require(len(rows) == 1, f'Expected one level-change command in group {owner["group"]}')
        offset, command = rows[0]
        packed = command[5]
        Hive.require(packed >> 5 == entry and packed & 31 == LEVEL[destination], f'Route destination differs in group {owner["group"]}')
        record = source['records'][region]
        polygon = [[source['vertices'][v][0] / 65536, -source['vertices'][v][1] / 65536] for v in record[6:10]]
        arrivals = [a for a in dest['arrivals'] if a[4] == entry]
        Hive.require(len(arrivals) == 1, 'Expected one destination arrival')
        x, y, heading, support, selector, flags, tail = arrivals[0]
        routes[area].append(dict(region=region, polygon=polygon, floor=min(slope_corners(source['records'], region)),
                                 ceiling=max(slope_corners(source['records'], region, True)), destination=destination,
                                 entry=entry, arrival=[x, max(slope_corners(dest['records'], support)) + Hive.BODY_HEIGHT, -y],
                                 heading=heading, event=owner['event'], group=owner['group'], command_hex=command.hex(),
                                 command_source_offset=source['offset'] + source['start'] + offset))
    for regions, exit_region in SLICE_EXITS:
        source = sources['dark_halls']
        base = next(r for r in routes['dark_halls'] if r['region'] == exit_region)
        points = [(source['vertices'][v][0] / 65536, -source['vertices'][v][1] / 65536) for region in regions for v in source['records'][region][6:10]]
        routes['dark_halls'].append(dict(base, region=regions[0], regions=list(regions), workaround_for=exit_region, polygon=[list(p) for p in hull(points)],
                                         floor=min(min(slope_corners(source['records'], r)) for r in regions),
                                         ceiling=max(max(slope_corners(source['records'], r, True)) for r in regions)))
    jungle = sources['jungle']
    cellar = dict(CELLAR)
    cellar['arrival'] = [CELLAR['native'][0], max(slope_corners(jungle['records'], CELLAR['region'])) + Hive.BODY_HEIGHT, -CELLAR['native'][1]]
    out = dict(version=1, cellar=cellar, routes=routes,
               scope='Original MCEL hotspot1 exit, L4 pocket region3205 -> L7 entry1, L7 exits -> L4 entry6. Grounded polygon admission (hive_route.gd adapter).')
    target = output / 'assets/lol2/generated/dark_halls_routes/routes.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(out, indent=1) + '\n')
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output-root', type=Path, required=True)
    a = p.parse_args()
    try:
        out = prepare(a.game.resolve(), a.output_root.resolve())
    except (ValueError, OSError, KeyError, IndexError, struct.error) as error:
        p.error(str(error))
    print(f"PASS Dark Halls routes: entry region3205 -> L7 entry1, {len(out['routes']['dark_halls'])} exits -> L4 entry6")


if __name__ == '__main__':
    main()
