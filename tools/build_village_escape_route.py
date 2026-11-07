#!/usr/bin/env python3
"""Build the continuous earned village-escape walk (tests/fixtures/village_escape_route.json) around the native
player-impassable regions, with the same source-neighbour BFS as tools/build_jungle_blocker_routes.py.

  python3 tools/build_village_escape_route.py --geometry ~/lol2_out/jungle_geometry_20260914/geometry.json

Segments (all on the blocker-avoiding graph): weapon-shop door -> village gate admission (region2443) -> inside the
gate -> the region before the Confidante start region3408 (so the barrel is seen and control123 idles, but the meeting
does not start) -> the tavern -> out through the gate passage -> back to the tavern -> from the betrayal return point
to the closed leaf78 in the gate passage. The monastery leg reuses hive_quest_walk_routes.tavern_to_monastery from its
point nearest the gate.
"""
import argparse, hashlib, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_jungle_blocker_routes as B

SHOP = (-5231.0, -637.0)
OUTSIDE = (-1300.0, -5250.0)
INSIDE = (-1479.5, -5169.0)
TAVERN = (-1630.0, -3900.0)
RETURN = (-1718.0, -3961.0)
LEAF = (-1440.0, -5300.0)
# Source creature spawn on a portal centreline: Jungle dino actor24 stands at (-2910,-4984)
# (scripts/lol2/jungle_dino_population_source.json), 19 units from the 3756->3759 portal midpoint; capsule radii 14+15
# need 29. Sample that portal at 0.75 (76 units clear), toward the next waypoint. Live dinosaurs still move and attack.
CREATURE_STEERING = [(3756, 3759, .75, 24)]
# The dinosaur herd actors 24-28 (around -2910..-2529, -5046..-4848) stands beside the direct shop->gate path; the
# alert range is 240 (jungle_dino_population_state.ALERT_RANGE) and a bite is 10 of 30 health. A player avoids it:
# shop_to_gate leaves out every region with a corner within 260 of a herd spawn (the campaign jungle_to_village route
# stays over 1200 away). Live dinosaurs can still wander; the route test fights or steps around them.
HERD = [24, 25, 26, 27, 28]
HERD_CLEARANCE = 260.0


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--geometry', type=Path, required=True); p.add_argument('--check', action='store_true')
    a = p.parse_args()
    raw = a.geometry.read_bytes(); assert hashlib.sha256(raw).hexdigest() == B.GEOMETRY, 'Unsupported geometry export'
    g = json.loads(raw)
    blocked = {int(x) for x in json.loads((ROOT / 'assets/lol2/generated/region_blockers/L4_HJ.json').read_text())['blocked_regions']}
    graph = B.walkable(g, blocked)
    herd = [(a['position'][0], a['position'][2]) for a in json.loads((ROOT / 'scripts/lol2/jungle_dino_population_source.json').read_text())['actors'] if a['actor'] in HERD]
    near_herd = {i for i, r in enumerate(g['regions']) if any(B.math.dist((g['vertices_fixed'][v][0] / 65536, -g['vertices_fixed'][v][1] / 65536), h) < HERD_CLEARANCE for v in r['vertex_indices'] for h in herd)}
    herd_free = B.walkable(g, blocked | near_herd)
    def seg(start, region, end, avoid_herd=False):
        r = B.route(herd_free if avoid_herd else graph, B.locate(g, start), (region, list(end)))
        assert not set(r['regions']) & blocked, r['regions']
        r['creature_steering'] = []
        for source, target, fraction, actor in CREATURE_STEERING:
            pairs = list(zip(r['regions'], r['regions'][1:]))
            if (source, target) not in pairs: continue
            i = pairs.index((source, target))
            r['points'][i] = B.portal_point(g, source, target, fraction)
            r['creature_steering'].append(dict(source=source, destination=target, fraction=fraction, actor=actor, point=r['points'][i]))
        return r
    before_meeting = tuple(B.centroid(g, 3409))
    out = dict(
        shop_to_gate=seg(SHOP, 2443, OUTSIDE, avoid_herd=True),
        gate_to_inside=seg(OUTSIDE, 3814, INSIDE),
        inside_to_confidante=seg(INSIDE, 3409, before_meeting),
        confidante_to_tavern=seg(before_meeting, 3501, TAVERN),
        tavern_to_outside=seg(TAVERN, 2443, OUTSIDE),
        outside_to_tavern=seg(OUTSIDE, 3501, TAVERN),
        return_to_leaf=seg(RETURN, 3805, LEAF))
    assert min(B.math.dist(p, h) for p in out['shop_to_gate']['points'] for h in herd) >= 240, 'shop route within the herd alert range'
    assert 3408 not in out['inside_to_confidante']['regions'] and 3805 in out['tavern_to_outside']['regions']
    text = json.dumps(dict(version=1, geometry_sha256=B.GEOMETRY, blocked_regions_sha256=hashlib.sha256((ROOT / 'assets/lol2/generated/region_blockers/L4_HJ.json').read_bytes()).hexdigest(),
                           points=dict(shop=SHOP, outside=OUTSIDE, inside=INSIDE, tavern=TAVERN, return_point=RETURN, leaf=LEAF), routes=out), indent=1) + '\n'
    path = ROOT / 'tests/fixtures/village_escape_route.json'
    if a.check:
        print('SAME' if path.read_text() == text else 'DIFFERS'); return
    path.write_text(text)
    print('PASS village escape route:', {k: len(v['points']) for k, v in out.items()})


if __name__ == '__main__':
    main()
