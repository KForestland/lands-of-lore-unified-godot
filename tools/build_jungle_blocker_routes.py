#!/usr/bin/env python3
"""Rebuild the Jungle (L4_HJ) walk-route test fixtures around the native player-impassable regions.

  python3 tools/build_jungle_blocker_routes.py --geometry GEOMETRY [--no-avoid] [--check]

Inputs:
- --geometry: the L4_HJ source geometry export the original fixture builders used (sha256 c02746be..., archive
  517afe6d...; ~/lol2_out/jungle_geometry_20260914/geometry.json). Its region graph equals the one the blocker
  producer used (geometry d960c3af...): same regions, neighbours, corners and vertices.
- assets/lol2/generated/region_blockers/L4_HJ.json: blocked_regions (native region word +0x1C bit0, op197-toggled
  regions excluded), as tools/prepare_region_blockers.py writes it.
- assets/lol2/generated/hive_routes/routes.json (Hive entrance polygon) and creature_nav/L4_HJ.json (Dark Halls entry6
  route), both in the repo.

Method: the former per-fixture builders (build_hive_quest_walk.route/walkable, build_museum_walk_route.build: source
neighbour BFS, standing clearance >= 47, portal width >= 32, step <= 32, rising-portal samples) and their recorded
starts, ends and obstacle steering, reproduced here in one place. With avoidance (default) every edge into a blocked
region is removed from the graph first, so no route enters a region the original refuses the player. --no-avoid
rebuilds the former fixtures; --check compares a rebuild with the committed files (on the pre-avoidance fixtures,
--no-avoid --check reported all 8 former files SAME).
Only the Jungle routes are rewritten; Hive (L5_HC) routes in the same files are kept byte-for-byte as data.
"""
import argparse, copy, hashlib, json, math
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIX = ROOT / 'tests/fixtures'
ARCHIVE = '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'
GEOMETRY = 'c02746be15ab2343c91d9a4d866995b30183763d0ee6369695193b5b262d60b4'
DEPARTURE_STEERING = [(1906, 1905, .25), (1905, 1902, .125), (1902, 3788, .25)]
# Portals of the blocker-avoiding paths where the centreline stalls on terrain in the live Jungle (headless scan with
# the production grounded mover, tmp-style diagnostic): 598->3890 has a 10-unit floor step at its southern end (598 30
# vs 3890 20) and the walk stops on the riser; samples at 0.70-0.85 toward the northern (level) end pass, 0.75 is used.
TERRAIN_STEERING = [(598, 3890, .75)]


def inside(p, poly):
    result = False
    for a, b in zip(poly, poly[1:] + poly[:1]):
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]: result = not result
    return result


def walkable(data, blocked):
    result = copy.deepcopy(data)
    for region in result['regions']:
        for edge, neighbor in enumerate(region['neighbors']):
            if neighbor is None: continue
            if neighbor in blocked:
                region['neighbors'][edge] = None
                continue
            other = data['regions'][neighbor]
            vertices = [region['vertex_indices'][edge], region['vertex_indices'][(edge + 1) % 4]]
            differences = [abs(region['floor_corners'][region['vertex_indices'].index(v)] -
                               other['floor_corners'][other['vertex_indices'].index(v)])
                           for v in vertices if v in other['vertex_indices']]
            if len(differences) != 2 or min(differences) > 32: region['neighbors'][edge] = None
    return result


def bfs(data, start, destination, minimum_clearance=47, minimum_portal_width=32):
    goal, endpoint = destination
    regions = data['regions']
    previous = {start: None}
    queue = deque([start])
    while queue:
        current = queue.popleft()
        if current == goal: break
        for edge, neighbor in enumerate(regions[current]['neighbors']):
            if neighbor is None or neighbor in previous: continue
            indices = regions[current]['vertex_indices']
            a, b = (data['vertices_fixed'][indices[j % 4]] for j in (edge, edge + 1))
            if math.dist(a, b) / 65536 < minimum_portal_width: continue
            region = regions[neighbor]
            if min(c - f for c, f in zip(region['ceiling_corners'], region['floor_corners'])) < minimum_clearance: continue
            previous[neighbor] = current
            queue.append(neighbor)
    if goal not in previous: raise ValueError(f'No standing-clearance adjacency route from {start} to {goal}')
    route = []
    current = goal
    while current is not None:
        route.append(current)
        current = previous[current]
    route.reverse()
    points = []
    for source, target in zip(route, route[1:]):
        region = regions[source]
        edge = region['neighbors'].index(target)
        indices = region['vertex_indices']
        a, b = (data['vertices_fixed'][indices[j % 4]] for j in (edge, edge + 1))
        points.append([(a[0] + b[0]) / 131072, -(a[1] + b[1]) / 131072])
    points.append(list(endpoint))
    return dict(regions=route, points=points, source_sha256=data['source']['sha256'],
                minimum_clearance=minimum_clearance, minimum_portal_width=minimum_portal_width,
                scope='Source neighbor BFS with standing-clearance and portal-width filters; capsule traversal, special connectors and native progression not established.')


def route(data, start, destination):
    result = bfs(data, start, destination)
    adjustments = []
    for index, (source, target) in enumerate(zip(result['regions'], result['regions'][1:])):
        a, b = data['regions'][source], data['regions'][target]
        edge = a['neighbors'].index(target)
        ids = [a['vertex_indices'][edge], a['vertex_indices'][(edge + 1) % 4]]
        gains = [b['floor_corners'][b['vertex_indices'].index(v)] - a['floor_corners'][a['vertex_indices'].index(v)] for v in ids]
        if sum(gains) / 2 <= 31.5: continue
        points = [[data['vertices_fixed'][v][0] / 65536, -data['vertices_fixed'][v][1] / 65536] for v in ids]
        margin = max(0.1, 16 / math.dist(*points))
        t = margin if gains[0] < gains[1] else 1 - margin
        gain = gains[0] * (1 - t) + gains[1] * t
        if gain > 31.5 or margin >= 0.5: raise ValueError(f'No capsule-safe rising portal sample {source}->{target}: {gains}')
        result['points'][index] = [points[0][axis] * (1 - t) + points[1][axis] * t for axis in range(2)]
        adjustments.append(dict(source=source, destination=target, fraction=t, expected_rise=gain))
    result['portal_adjustments'] = adjustments
    return result


def portal_point(g, source, target, fraction):
    edge = g['regions'][source]['neighbors'].index(target)
    ids = g['regions'][source]['vertex_indices']
    a, b = [g['vertices_fixed'][ids[k % 4]] for k in [edge, edge + 1]]
    return [(a[0] * (1 - fraction) + b[0] * fraction) / 65536, -(a[1] * (1 - fraction) + b[1] * fraction) / 65536]


def locate(g, p):
    found = [i for i, r in enumerate(g['regions'])
             if inside(p, [(g['vertices_fixed'][v][0] / 65536, -g['vertices_fixed'][v][1] / 65536) for v in r['vertex_indices']])
             and min(c - f for c, f in zip(r['ceiling_corners'], r['floor_corners'])) >= 47]
    assert len(found) == 1, (p, found)
    return found[0]


def centroid(g, region):
    v = [g['vertices_fixed'][i] for i in g['regions'][region]['vertex_indices']]
    return (sum(p[0] for p in v) / 262144, -sum(p[1] for p in v) / 262144)


def reuse_steering(r, known):
    for k in known:
        for index, (a, b) in enumerate(zip(r['regions'], r['regions'][1:])):
            if (a, b) == (k['source'], k['destination']) or (b, a) == (k['source'], k['destination']): r['points'][index] = k['point']


def entry6_route(blocked):
    """Dark Halls entry6 -> monastery entrance over the creature-nav portal graph (tools/build_dark_halls_entry6_route.py)."""
    nav_path = ROOT / 'assets/lol2/generated/creature_nav/L4_HJ.json'
    nav = json.loads(nav_path.read_text()); R = nav['regions']
    def quad(q, x, z): return inside((x, z), [tuple(p) for p in q])
    def region_at(x, z, y):
        hits = [i for i, r in enumerate(R) if r[0] and quad(r[0], x, z)]
        return [i for i in hits if R[i][1] - 40 <= y <= R[i][2] + 40] or hits
    start = region_at(4561, 3282, 34)[0]
    goal_point = (4264.0, 2375.0)
    goal = region_at(*goal_point, 42)
    prev = {start: None}; dq = deque([start])
    while dq:
        u = dq.popleft()
        if u in goal: break
        for n, px, pz in R[u][3]:
            if n in prev or n in blocked: continue
            prev[n] = (u, px, pz); dq.append(n)
    g = next(x for x in goal if x in prev)
    path, pts, u = [], [], g
    while prev[u] is not None:
        p, px, pz = prev[u]; path.append(u); pts.append([px, pz]); u = p
    path.append(start); path.reverse(); pts.reverse(); pts.append(list(goal_point))
    return {'regions': path, 'points': pts, 'source': 'creature_nav/L4_HJ.json',
            'source_sha256': hashlib.sha256(nav_path.read_bytes()).hexdigest(),
            'scope': 'Region-portal BFS (creature-nav adapter graph: clearance>=47, step<=32, portal>=24) from Jungle entry6 to the monastery entrance; capsule traversal checked only by the walk.'}


def repair(g, raw, former, blocked):
    """Keeps a hand-built route's regions and points, re-routing only each run of blocked regions: source-neighbour
    BFS (clearance 47, width 32, no step filter) from the region before the run to the region after it, with portal
    midpoints for the new portals. Idempotent on a route that crosses no blocked region."""
    regions, points = list(former['regions']), [list(p) for p in former['points']]
    i = 0
    while i < len(regions):
        if regions[i] not in blocked: i += 1; continue
        j = i
        while regions[j] in blocked: j += 1
        assert i > 0 and j < len(regions), 'route starts or ends in a blocked region'
        part = bfs(raw, regions[i - 1], (regions[j], (0, 0)))
        regions[i - 1:j + 1] = part['regions']
        # points[k] is the portal regions[k] -> regions[k+1]; replace the portals of the re-routed stretch.
        points[i - 1:j] = part['points'][:-1]
        i = i - 1 + len(part['regions'])
    # A hand-built route may jump between regions that are not neighbours (3813 -> 2443 skips 3811/3805); with the
    # blockers on, that straight leg grazes the 3813->3806 blocker corner within the capsule radius. Fill such gaps
    # with the source portals (BFS as above), keeping the former point where it already is the first portal.
    k = 0
    while k + 1 < len(regions):
        a, b = regions[k], regions[k + 1]
        if a != b and b not in g['regions'][a]['neighbors']:
            part = bfs(raw, a, (b, (0, 0)))
            regions[k:k + 2] = part['regions']
            points[k:k + 1] = part['points'][:-1]
            k += len(part['regions']) - 1
        else: k += 1
    # Two re-routed runs can meet in a back-and-forth (405 -> 390 -> 405): cut every non-adjacent revisit. Adjacent
    # repeats are the former route's own extra waypoints inside one region and stay.
    k = 0
    while k < len(regions):
        later = [m for m in range(k + 2, len(regions)) if regions[m] == regions[k]]
        if later:
            m = later[-1]
            del regions[k + 1:m + 1]
            del points[k:m]
        k += 1
    result = dict(former); result['regions'] = regions; result['points'] = points
    result['scope'] = former['scope'] + ' Runs through native impassable regions re-routed (tools/build_jungle_blocker_routes.py).'
    if 'Runs through' in former['scope']: result['scope'] = former['scope']
    return result


def build(g, blocked):
    graph = walkable(g, blocked)
    out = {}
    # Earned dragon arrival -> human Hive entrance (former build_earned_jungle_hive_walk.py).
    entry = json.loads((ROOT / 'assets/lol2/generated/hive_routes/routes.json').read_text())['jungle']
    end = [sum(p[i] for p in entry['polygon']) / len(entry['polygon']) for i in range(2)]
    r = route(graph, locate(g, (353, -4909)), (entry['region'], end))
    # Centerline clips the inside wall turning into the 32-unit passage; sample this portal toward its southern end.
    r['obstacle_steering'] = []
    if (1667, 1665) in zip(r['regions'], r['regions'][1:]):
        i = r['regions'].index(1667)
        r['points'][i] = portal_point(g, 1667, 1665, .75)
        r['obstacle_steering'].append({'source': 1667, 'destination': 1665, 'fraction': .75, 'point': r['points'][i]})
    out['earned_jungle_hive_walk_route'] = r
    # Monastery exit -> central exit region (former build_act_one_departure_walk.py).
    r = route(graph, 3149, (3188, centroid(g, 3188)))
    # Source wall chain 3330..3334 crosses the corridor centreline; walk its northern side.
    r['obstacle_steering'] = []
    for source, target, fraction in DEPARTURE_STEERING:
        pairs = list(zip(r['regions'], r['regions'][1:]))
        if (source, target) not in pairs: continue
        i = pairs.index((source, target))
        r['points'][i] = portal_point(g, source, target, fraction)
        r['obstacle_steering'].append(dict(source=source, destination=target, blocking_regions=[3330, 3331, 3332, 3333, 3334], fraction=fraction, point=r['points'][i]))
    out['act_one_departure_route'] = r
    known = r['obstacle_steering']
    # Quest walks (former build_hive_quest_walk.py, Jungle part).
    out['hive_quest_walk_routes'] = {
        'jungle_to_village': route(graph, 2811, (2443, (-1300, -5250))),
        'village_to_followup': route(graph, 3811, (3262, (-1660, -4300))),
        'followup_to_tavern': route(graph, 3262, (3501, (-1630, -3900))),
        'tavern_to_monastery': route(graph, 3501, (3148, (4250, 2377)))}
    out['hive_flute_return_routes'] = {'monastery_to_hive': route(graph, 3149, (2809, (-6491, 4877.75)))}
    out['hive_rune_return_routes'] = {'jungle_to_monastery': route(graph, 2811, (3148, (4250, 2377)))}
    # Shops (former build_magic_shop_walk.py / build_weapon_shop_walk.py).
    start, ment = (4181, 2377), (4264, 2375)
    shop_graph = copy.deepcopy(graph)
    # The former fixture planned around the open Gate79 leaf (central south portal) via the west side. That west side
    # crosses bit0 regions: with them refused, the village gate passage (2443/3805) is the only way to the magic shop,
    # so the detour is applied only when a route exists without the gate.
    for region in shop_graph['regions']: region['neighbors'] = [None if n in [2443, 3805] else n for n in region['neighbors']]
    try:
        magic = {'to_shop': route(shop_graph, locate(g, start), (locate(g, (-1066, -5676)), (-1066, -5676))),
                 'to_monastery': route(shop_graph, locate(g, (-1141, -5679)), (3148, ment))}
    except ValueError:
        magic = {'to_shop': route(graph, locate(g, start), (locate(g, (-1066, -5676)), (-1066, -5676))),
                 'to_monastery': route(graph, locate(g, (-1141, -5679)), (3148, ment))}
    weapon = {'to_shop': route(graph, locate(g, start), (locate(g, (-5310, -610)), (-5310, -610))),
              'to_monastery': route(graph, locate(g, (-5245, -631)), (3148, ment))}
    for r in list(magic.values()) + list(weapon.values()): reuse_steering(r, known)
    out['magic_shop_walk'] = magic
    out['weapon_shop_walk'] = weapon
    out['dark_halls_entry6_monastery_route'] = entry6_route(blocked)
    for name, value in out.items():
        for r in ([value] if 'regions' in value else value.values()):
            for source, target, fraction in TERRAIN_STEERING:
                pairs = list(zip(r['regions'], r['regions'][1:]))
                for index, pair in enumerate(pairs):
                    if pair not in ((source, target), (target, source)): continue
                    r['points'][index] = portal_point(g, source, target, fraction)
                    r.setdefault('obstacle_steering', []).append(dict(source=pair[0], destination=pair[1], terrain_step=True, fraction=fraction, point=r['points'][index]))
    if blocked:
        # Chief-hut walk (tests/fixtures/chief_hut_walk_routes.json); its former builder is not in the repo, so these two
        # are rebuilt only with avoidance. inner_gate_to_pool: source-neighbour BFS without the step filter (the walk
        # test uses the production jump at stalled ridges, as the former scope says); pool_to_village: route() as above.
        raw = copy.deepcopy(g)
        for region in raw['regions']: region['neighbors'] = [None if n in blocked else n for n in region['neighbors']]
        former = json.loads((FIX / 'chief_hut_walk_routes.json').read_text())['inner_gate_to_pool']
        inner = repair(g, raw, former, blocked)
        out['chief_hut_walk_routes'] = {'inner_gate_to_pool': inner, 'pool_to_village': route(graph, 3756, (2443, (-1300, -5250)))}
    return out


def merged(name, rebuilt):
    """Whole-file JSON: Jungle routes replaced, any other (Hive) routes kept."""
    path = FIX / f'{name}.json'
    if name in ('earned_jungle_hive_walk_route', 'act_one_departure_route', 'dark_halls_entry6_monastery_route'): return rebuilt
    data = json.loads(path.read_text())
    for key, value in rebuilt.items(): data[key] = value
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--geometry', type=Path, required=True)
    parser.add_argument('--no-avoid', action='store_true', help='rebuild without blocker avoidance (the former fixtures)')
    parser.add_argument('--check', action='store_true', help='compare with the committed fixtures instead of writing')
    args = parser.parse_args()
    raw = args.geometry.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == GEOMETRY, 'unexpected geometry export'
    g = json.loads(raw)
    assert g['source']['sha256'] == ARCHIVE
    blockers = json.loads((ROOT / 'assets/lol2/generated/region_blockers/L4_HJ.json').read_text())
    assert blockers['archive_sha256'] == ARCHIVE
    blocked = set() if args.no_avoid else set(blockers['blocked_regions'])
    rebuilt = build(g, blocked)
    every = set(blockers['blocked_regions'])
    status = 0
    for name, value in rebuilt.items():
        data = merged(name, value)
        routes = {name: value} if 'regions' in value else value
        crossed = {k: len([x for x in v['regions'] if x in every]) for k, v in routes.items()}
        path = FIX / f'{name}.json'
        if args.check:
            # The DH entry6 fixture was written with indent=1 and no newline; compare as data.
            same = json.loads(path.read_text()) == json.loads(json.dumps(data))
            print(('SAME ' if same else 'DIFF ') + name, crossed)
            status |= 0 if same else 1
        else:
            path.write_text(json.dumps(data, indent=2) + '\n')
            print('wrote', name, {k: len(v['regions']) for k, v in routes.items()}, 'blocked crossed', crossed)
    raise SystemExit(status)


if __name__ == '__main__':
    main()
