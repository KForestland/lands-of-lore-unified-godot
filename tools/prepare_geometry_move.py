#!/usr/bin/env python3
"""Move one layout of a same-height overlap so it becomes stacked (L14 T3, lead decision 2026-11-13; DEVIATIONS row).

Owner F10 01-16-21 / 01-17-01 (r19f): in the Huline Temple a 24-region crawl tunnel (2520-2545, floor -20..45, ceiling
<= 80, the spider corridor) runs through a wooden room (floor 0, ceiling 160) at the same height; both are drawn at once.
This producer lowers the tunnel by DY and bends the tunnel beyond its joins into ramps, so the tunnel runs under the
room's floor. One spec, one transform, applied to every derived input so all consumers agree:

  delta(region, x, z) = -DEPTH(s)      region in MOVED or in the ramp set (tunnel regions near the centreline, never
                                       the room side); s = arclength of (x, z) projected on the tunnel's centreline
                      = 0              everywhere else
  DEPTH(s) (lead option A, shaped dip): the least drop that keeps the tunnel's ceiling CLEAR below the room's floor
  wherever it lies under the room, eased off at no more than GRADE (rise per run) along the tunnel, and checked never
  to take the tunnel's floor below the floor of a KEEP layout sharing its space (corridor 3185 at the west mouth).
Measured along the tunnel, so every cross-section stays level (no sideways tilt).
Floor and ceiling move by the same delta at every point, so the crawl clearance is unchanged.

Writes (a) the moved map pack <pack>/area_moved.json (face points), (b) creature_nav/<AREA>.moved.json (floor ranges),
(c) the spec scripts/lol2/geometry_moves/<AREA>.json (regions, joins, per-region corner deltas, input/output sha256)
that tools/prepare_region_mover.py and the game read. The original files are left untouched; the game picks the moved
pair only when the spec's sha256 match and meta lol2_geometry_move_off is not set.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))

ROOT = Path(__file__).resolve().parents[1]
MAPS = Path('~/lol2_out/all_maps_20260922')
MOVES = {
    'L14_HT': [dict(zone='T3', kind='shaped_dip',moved=[2520, 2521, 2522, 2523, 2524, 2525, 2526, 2527, 2528, 2529, 2530, 2531, 2532, 2533, 2534, 2535,
                          2536, 2537, 2538, 2539, 2540, 2542, 2543, 2545],
                   room_seed=2768, dy=-100, ramp=150.0, margin=15.0, lateral=60.0, clear=5.0, grade=0.72, keep=[3185],
                   # the tunnel's centreline: centres of its full-height strips, from 2518 (west, past the ramp) to 2554 (east)
                   centreline=[[1605, -4729], [1544, -4783], [1497, -4846], [1478, -4918], [1458, -4982], [1408, -5034], [1348, -5069], [1286, -5088],
                               [1214, -5082], [1145, -5102], [1086, -5150], [1044, -5193], [998, -5252], [994, -5342],
                               [1023, -5464], [1067, -5564]],
                   reason='owner F10 2026-11-13 01-16-21 (1273,-5066) and 01-17-01 (1388,-5076): crawl tunnel and wooden '
                          'room share the same space at height 0 (zone T3); lead approved the move 01:49Z'),
               dict(zone='T14', kind='floor_raise', regions=[34, 36, 38, 40], floor_to=25,
                    reason='owner F10 2026-11-12 r36/3890 (wall 8260 across the lower corridor): the trench behind the hall '
                           'wall (34/36/38/40, floor -80, ceiling 90) shares the corridor 3874..3906 (floor -80, ceiling 20); '
                           'lead 2026-11-13: small-zone table, T14 first; floor-only raise keeps the windows and reachability '
                           '(sills made solid for the player, row with this move)')],
    'L10_DC': [dict(zone='EMP', kind='floor_lower', floor_from=-50, floor_to=-66, seed=3883,
                    regions=[601, 3788, 3789, 3790, 3801, 3802, 3803, 3804, 3805, 3806, 3807, 3808, 3809, 3811, 3813, 3814, 3815,
                             3816, 3817, 3818, 3819, 3820, 3829, 3838, 3846, 3862, 3863, 3864, 3865, 3867, 3868, 3880, 3881],
                    carry_assemblies=[143, 175],
                    reason='Grok L10_SHOWTHROUGH_FRAMES_20261113 box127/box125/door143/remains, lead 2026-11-14: the Emperor tomb '
                           'hall (floor -50, ceiling 50..200) shares its plan with the yard (floor 0, ceiling 175), so the eye '
                           '(feet + 56) stands 6 above the yard floor; its 33 floors at -50 go to -66 (eye -10), ceilings kept, '
                           'walls on their edges extended down, doors 143/175 stretched to the new floor; the catacomb ceiling '
                           '(-75) stays 9 below')],
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def seg_dist(px, pz, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L = dx * dx + dz * dz
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / L))
    return math.hypot(px - a[0] - t * dx, pz - a[1] - t * dz)


def shaped_dip(spec, area, root, regs, quad, nb):
    """One zone of kind 'shaped_dip' (T3): returns its moved and ramp regions, joins, per-corner drops and the point
    delta function, plus the fields it records in the spec."""
    moved = set(spec['moved'])
    # the room side: the same-height overlap zone around room_seed, minus the moved side (from the overlap list)
    pairs = json.loads((root / f'scripts/lol2/region_mover/{area}_overlaps.json').read_text())['pairs']
    adj = {}
    for a, b, _ in pairs:
        adj.setdefault(a, set()).add(b); adj.setdefault(b, set()).add(a)
    zone, stack = set(), [spec['room_seed']]
    while stack:
        x = stack.pop()
        if x not in zone:
            zone.add(x); stack += list(adj.get(x, ()))
    room = zone - moved
    assert moved <= zone, 'moved regions must all lie in the overlap zone'
    # joins: edges of moved regions whose neighbour is outside the moved set
    joins = []
    for r in sorted(moved):
        q = quad[r]
        for e, n in enumerate(nb[r]):
            if n >= 0 and n not in moved:
                assert n not in room, f'join {r}->{n} enters the room side'
                joins.append(dict(region=r, edge=e, neighbour=n, a=q[e], b=q[(e + 1) % 4]))
    room_quads = [quad[r] for r in room if len(quad[r]) == 4]
    room_quads_f = [(quad[r], regs[r]['floor_corners']) for r in room if len(quad[r]) == 4]
    from prepare_region_mover import _area  # noqa: E402

    def inside(x, z, q):
        hit = False
        for i in range(len(q)):
            (x1, z1), (x2, z2) = q[i], q[(i + 1) % len(q)]
            if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
                hit = not hit
        return hit

    def room_dist(x, z):
        best = math.inf
        for q in room_quads:
            if inside(x, z, q):
                return 0.0
            for i in range(4):
                best = min(best, seg_dist(x, z, q[i], q[(i + 1) % 4]))
        return best
    line = spec['centreline']
    cum = [0.0]
    for a, b in zip(line, line[1:]):
        cum.append(cum[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))

    def arc(x, z, lateral=False):
        best, at = math.inf, 0.0
        for i, (a, b) in enumerate(zip(line, line[1:])):
            dx, dz = b[0] - a[0], b[1] - a[1]
            L = dx * dx + dz * dz
            t = max(0.0, min(1.0, ((x - a[0]) * dx + (z - a[1]) * dz) / L))
            d = math.hypot(x - a[0] - t * dx, z - a[1] - t * dz)
            if d < best:
                best, at = d, cum[i] + t * math.sqrt(L)
        return best if lateral else at
    # where the tunnel lies under the room: every vertex AND a grid of points over every moved region (a point off the
    # centreline can project past the last vertex inside the room)
    # Shaped dip (lead option A, 2026-11-13): NEED(s) = how far the tunnel must drop at arclength s so its ceiling is
    # CLEAR below the room's floor wherever it lies under the room; CAP(s) = how far it may drop where it shares its
    # space with another layout (KEEP: its floor stays at or above that layout's floor, e.g. corridor 3185 at the
    # west mouth). DEPTH(s) = max over s' of NEED(s') - GRADE * |s - s'| (never steeper than GRADE), checked <= CAP.
    def interp(q, c, x, z):
        for t in ((0, 1, 2), (0, 2, 3)):
            (ax, az), (bx, bz), (cx, cz) = (q[k] for k in t)
            det = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz)
            if abs(det) < 1e-9:
                continue
            u = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / det
            v = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / det
            w = 1 - u - v
            if u >= -1e-4 and v >= -1e-4 and w >= -1e-4:
                return u * c[t[0]] + v * c[t[1]] + w * c[t[2]]
        return min(c)
    step = 5.0
    need, cap = {}, {}
    # the tunnel itself: the moved regions and the regions reached from them through neighbours (never the room side)
    # that lie near its centreline - other layouts nearby are not part of it
    near, stack = set(), [n for r in moved for n in nb[r] if n >= 0]
    while stack:
        x = stack.pop()
        if x in near or x in moved or x in room or len(quad[x]) != 4:
            continue
        if min(arc(*p, lateral=True) for p in quad[x]) > spec['lateral']:
            continue
        near.add(x)
        stack += [n for n in nb[x] if n >= 0]
    keep = [(quad[k], regs[k]['floor_corners'], k) for k in spec['keep']]
    for r in near | moved:
        q = quad[r]
        for i in range(13):
            for j in range(13):
                u, v = i / 12, j / 12
                x = (q[0][0] * (1 - u) + q[1][0] * u) * (1 - v) + (q[3][0] * (1 - u) + q[2][0] * u) * v
                z = (q[0][1] * (1 - u) + q[1][1] * u) * (1 - v) + (q[3][1] * (1 - u) + q[2][1] * u) * v
                if r not in moved and arc(x, z, lateral=True) > spec['lateral']:
                    continue
                key = round(arc(x, z) / step)
                ceil = interp(q, regs[r]['ceiling_corners'], x, z)
                fl = interp(q, regs[r]['floor_corners'], x, z)
                for rq in room_quads_f:
                    if inside(x, z, rq[0]):
                        need[key] = max(need.get(key, 0.0), ceil - interp(rq[0], rq[1], x, z) + spec['clear'])
                for kq, kf, _ in keep:
                    if inside(x, z, kq):
                        cap[key] = min(cap.get(key, math.inf), fl - interp(kq, kf, x, z))
    top = max(int(cum[-1] / step) + 1, max(need) + 1)
    depth = {k: max([0.0] + [n - spec['grade'] * step * abs(k - kk) for kk, n in need.items()]) for k in range(top + 1)}
    over = {k: (round(depth[k], 1), round(c, 1)) for k, c in cap.items() if depth.get(k, 0) > c + 1e-6}
    assert not over, f'the dip breaks a kept layout (s: depth, cap): {over}'

    # A big region's face is flat between its corners, so a profile that bends inside it can leave its middle short of
    # the drop. Solved per native vertex (regions sharing a vertex move it alike, no crack): start from the eased
    # profile, then wherever a sampled point of a moved region's ceiling under the room is still higher than the room's
    # floor - CLEAR, deepen that triangle's corners by their share of the point (least change); re-ease the profile from
    # the corners' depths and repeat until nothing pokes up.
    vkey = lambda p: (round(p[0], 2), round(p[1], 2))
    tri_of = {}
    samples = []
    for r in moved:
        q = quad[r]
        for i in range(13):
            for j in range(13):
                u, v = i / 12, j / 12
                x = (q[0][0] * (1 - u) + q[1][0] * u) * (1 - v) + (q[3][0] * (1 - u) + q[2][0] * u) * v
                z = (q[0][1] * (1 - u) + q[1][1] * u) * (1 - v) + (q[3][1] * (1 - u) + q[2][1] * u) * v
                for rq in room_quads_f:
                    if inside(x, z, rq[0]):
                        limit = interp(rq[0], rq[1], x, z) - spec['clear']
                        for t in ((0, 1, 2), (0, 2, 3)):
                            (ax, az), (bx, bz), (cx, cz) = (q[k] for k in t)
                            det = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz)
                            if abs(det) < 1e-9:
                                continue
                            w0 = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / det
                            w1 = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / det
                            w2 = 1 - w0 - w1
                            if min(w0, w1, w2) >= -1e-4:
                                ceil = interp(q, regs[r]['ceiling_corners'], x, z)
                                samples.append(([vkey(q[k]) for k in t], (w0, w1, w2), ceil - limit))
                                break
                        break
    vertices = {vkey(p) for r in moved | near for p in quad[r]}
    vertex_need = {}
    for _ in range(30):
        vd = {k: max(depth.get(round(arc(*k) / step), 0.0), vertex_need.get(k, 0.0)) for k in vertices}
        for _ in range(400):
            worst = 0.0
            for keys, w, needd in samples:
                have = sum(wi * vd[k] for k, wi in zip(keys, w))
                short = needd - have
                if short > 0.01:
                    worst = max(worst, short)
                    norm = sum(wi * wi for wi in w)
                    for k, wi in zip(keys, w):
                        vd[k] += short * wi / norm
            if worst <= 0.01:
                break
        grew = {k: d for k, d in vd.items() if d > vertex_need.get(k, 0.0) + 0.01 and d > depth.get(round(arc(*k) / step), 0.0) + 0.01}
        if not grew:
            break
        for k, d in grew.items():
            vertex_need[k] = d
            kk = round(arc(*k) / step)
            need[kk] = max(need.get(kk, 0.0), d)
        depth = {k: max([0.0] + [n - spec['grade'] * step * abs(k - kk) for kk, n in need.items()]) for k in range(top + 1)}
    over = {k: (round(depth[k], 1), round(c, 1)) for k, c in cap.items() if depth.get(k, 0) > c + 1e-6}
    assert not over, f'the dip breaks a kept layout (s: depth, cap): {over}'

    def weight(x, z):
        k = round(arc(x, z) / step)
        d = max(depth.get(k, 0.0), vertex_need.get((round(x, 2), round(z, 2)), 0.0))
        return d / -float(spec['dy'])

    def dist(x, z):   # 0 where the full drop applies; grows outside; off the tunnel (> LATERAL from its line) = never
        if arc(x, z, lateral=True) > spec['lateral']:
            return math.inf
        return (1.0 - weight(x, z)) * spec['ramp']
    # ramp set: tunnel regions reached from the joins through neighbours (never moved, never the room side) with a
    # vertex closer than RAMP to the room
    ramp, stack = set(), [j['neighbour'] for j in joins]
    while stack:
        x = stack.pop()
        if x in ramp or x in moved or x in room or len(quad[x]) != 4:
            continue
        if min(dist(*p) for p in quad[x]) >= spec['ramp']:
            continue
        ramp.add(x)
        stack += [n for n in nb[x] if n >= 0]

    def delta(region, x, z):
        if region in moved or region in ramp:
            return float(spec['dy']) * weight(x, z)
        return 0.0
    corner = {r: [round(delta(r, *p), 3) for p in quad[r]] for r in sorted(moved | ramp)}
    for r, ds in corner.items():   # no corner below a kept layout's floor where they share space
        for p, d in zip(quad[r], ds):
            for kq, kf, k in keep:
                if inside(p[0], p[1], kq):
                    fl = regs[r]['floor_corners'][quad[r].index(p)] + d
                    assert fl >= interp(kq, kf, *p) - 1e-6, f'region {r} corner {p} floor {fl:.1f} under kept {k}'

    extra = dict(dy=spec['dy'], ramp_length=spec['ramp'], room_side=sorted(room), joins=joins,
                 room_quads=[[[round(v, 3) for v in p] for p in quad[r]] for r in sorted(room) if len(quad[r]) == 4],
                 centreline=line, grade=spec['grade'], clear=spec['clear'], keep=spec['keep'],
                 depth_profile={str(int(k * step)): round(v, 2) for k, v in depth.items() if v > 0})
    return dict(zone=spec['zone'], kind=spec['kind'], reason=spec['reason'], moved=sorted(moved), ramp=sorted(ramp),
                corner=corner, delta=lambda region, x, z, face=None, y=None: delta(region, x, z), extra=extra)


def floor_raise(spec, area, root, regs, quad, nb):
    """A zone of kind 'floor_raise' (T14): the regions' floor rises to FLOOR_TO, the ceiling stays; floor faces move,
    wall faces move only their bottom points (those at the floor), ceilings do not move. Used where a sealed space (a
    trench seen through windows) must keep its upper part and leave the band of the layout it shares."""
    moved = set(spec['regions'])
    floors = {r: regs[r]['floor_corners'] for r in moved}
    for r in moved:
        assert len(set(floors[r])) == 1, f'floor_raise expects a flat floor in {r}'
        assert spec['floor_to'] < min(regs[r]['ceiling_corners']), f'{r}: raised floor reaches the ceiling'
    lift = {r: float(spec['floor_to'] - floors[r][0]) for r in moved}
    corner = {r: [round(lift[r], 3)] * 4 for r in sorted(moved)}

    def delta(region, x, z, face=None, y=None):
        if region not in moved or face is None:
            return lift.get(region, 0.0)
        if face.get('kind') == 'floor':
            return lift[region]
        if face.get('kind') in ('wall', 'source_wall') and y is not None and y <= floors[region][0] + 0.5:
            return lift[region]
        return 0.0
    return dict(zone=spec['zone'], kind=spec['kind'], reason=spec['reason'], moved=sorted(moved), ramp=[], corner=corner,
                ceiling={r: [0.0] * 4 for r in moved}, delta=delta, extra=dict(floor_to=spec['floor_to']))


def edge_key(face):
    """RegionEdgeRule.face_key (scripts/lol2/region_edge_rule.gd) for a vertical wall quad, else ''."""
    if face.get('kind') not in ('wall', 'source_wall'):
        return ''
    ends = []
    for p in face['points']:
        k = (p[0], p[2])
        if not any(abs(k[0] - e[0]) < 0.01 and abs(k[1] - e[1]) < 0.01 for e in ends):
            ends.append(k)
    if len(ends) != 2:
        return ''
    ys = [p[1] for p in face['points']]
    r = lambda v: int(math.floor(v + 0.5)) if v >= 0 else -int(math.floor(-v + 0.5))
    return '%s|%d,%d|%d,%d|%d|%d' % (face['kind'], r(ends[0][0]), r(ends[0][1]), r(ends[1][0]), r(ends[1][1]), r(min(ys)), r(max(ys)))


def point_in(x, z, q):
    c = False
    for i in range(len(q)):
        (x1, z1), (x2, z2) = q[i], q[(i + 1) % len(q)]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


def carry_band(r, regs, quad, nav_rows, moved):
    """[lo, hi): feet of an old save that stood in region r's original space. lo = its floor - 8; hi = the lower of its
    ceiling and the floor of any region over it (not moved, floor above r's floor, plan overlapping r's centre area)."""
    floor = min(regs[r]['floor_corners'])
    hi = float(min(regs[r]['ceiling_corners']))
    q = quad[r]
    probes = [((q[0][0] + q[2][0]) / 2, (q[0][1] + q[2][1]) / 2)] + [((p[0] * 3 + (q[0][0] + q[2][0]) / 2) / 4, (p[1] * 3 + (q[0][1] + q[2][1]) / 2) / 4) for p in q]
    for i, row in enumerate(nav_rows):
        if i in moved or not row or not row[0] or len(row[0]) < 3 or row[1] is None or row[1] <= floor:
            continue
        if any(point_in(x, z, row[0]) for x, z in probes):
            hi = min(hi, float(row[1]))
    return [floor - 8.0, hi]


def floor_lower(spec, area, root, regs, quad, nb):
    """A zone of kind 'floor_lower' (L10 EMP): flat floors at FLOOR_FROM go down to FLOOR_TO, ceilings stay. Every wall
    point at FLOOR_FROM that lies on a moved region's edge moves with the floor, whichever region owns the wall: a wall
    rising from the floor grows down, a riser down to a lower neighbour shrinks, a rim or box side standing on the floor
    grows down - so no lip and no slit opens along the moved edges. Carried assemblies (doors standing on the floor) move
    their bottom points the same way; their tops stay at the kept ceiling."""
    moved = set(spec['regions'])
    lo, to = float(spec['floor_from']), float(spec['floor_to'])
    for r in moved:
        assert set(regs[r]['floor_corners']) == {lo}, f'floor_lower expects flat floors at {lo} in {r}'
        assert to < min(regs[r]['ceiling_corners']), f'{r}: lowered floor reaches the ceiling'
    drop = to - lo
    corner = {r: [drop] * 4 for r in sorted(moved)}
    segs = [(quad[r][i], quad[r][(i + 1) % len(quad[r])]) for r in moved for i in range(len(quad[r]))]

    def on_edge(x, z):
        return any(seg_dist(x, z, a, b) < 0.5 for a, b in segs)
    carry = {f'static_{a}' for a in spec.get('carry_assemblies', [])}

    def delta(region, x, z, face=None, y=None):
        if face is None:
            return drop if region in moved else 0.0
        kind = face.get('kind')
        if kind == 'floor':
            return drop if region in moved else 0.0
        if kind in ('wall', 'source_wall') and y is not None and abs(y - lo) < 0.01 and on_edge(x, z):
            return drop
        if str(face.get('placement', '')) in carry and y is not None and abs(y - lo) < 0.01:
            return drop
        return 0.0
    return dict(zone=spec['zone'], kind=spec['kind'], reason=spec['reason'], moved=sorted(moved), ramp=[], corner=corner,
                ceiling={r: [0.0] * 4 for r in moved}, delta=delta, any_face=True,
                extra=dict(floor_from=lo, floor_to=to, carry_assemblies=spec.get('carry_assemblies', [])))


KINDS = {'shaped_dip': shaped_dip, 'floor_raise': floor_raise, 'floor_lower': floor_lower}


def build(area, maps, root):
    geo = json.loads((maps / area / 'geometry/geometry.json').read_text())
    V = geo['vertices_fixed']
    regs = geo['regions']
    quad = {i: [(V[v][0] / 65536, -V[v][1] / 65536) for v in (r.get('vertex_indices') or [])] for i, r in enumerate(regs)}
    nb = {i: [-1 if n is None else int(n) for n in (r.get('neighbors') or [None] * 4)] for i, r in enumerate(regs)}
    zones = [KINDS[z['kind']](z, area, root, regs, quad, nb) for z in MOVES[area]]
    owner = {}
    for z in zones:
        for r in z['corner']:
            assert r not in owner, f"region {r} is in zones {owner[r]} and {z['zone']}"
            owner[r] = z
    corner = {r: ds for z in zones for r, ds in z['corner'].items()}
    # (a) map pack
    pack_dir = root / f'assets/lol2/generated/maps/{area}'
    pack = json.loads((pack_dir / 'area.json').read_text())
    changed = 0
    wide = [z for z in zones if z.get('any_face')]
    key_moves = {}
    for face in pack['faces']:
        reg = face.get('region')
        reg = None if reg is None else int(reg)
        if reg in owner:
            zone_list = [owner[reg]]
        else:
            zone_list = wide
        if not zone_list:
            continue
        before = edge_key(face)
        touched = False
        for p in face['points']:
            d = sum(z['delta'](reg, p[0], p[2], face, p[1]) for z in zone_list)
            if d:
                p[1] = round(p[1] + d, 3)
                touched = True
        if reg in owner or touched:
            changed += 1
        after = edge_key(face)
        if touched and before and after != before:
            key_moves[after] = before
    out_pack = pack_dir / 'area_moved.json'
    out_pack.write_text(json.dumps(pack, separators=(',', ':')))
    # (b) creature nav floor ranges [quad, floor_min, floor_max, ...]
    nav_path = root / f'assets/lol2/generated/creature_nav/{area}.json'
    nav = json.loads(nav_path.read_text())
    nav_rows = json.loads(nav_path.read_text())['regions']
    for r, ds in corner.items():
        row = nav['regions'][r]
        if row and len(row) > 2:
            fc = regs[r].get('floor_corners') or [row[1]] * 4
            moved_floors = [f + d for f, d in zip(fc, ds)]
            row[1] = round(min(moved_floors), 3); row[2] = round(max(moved_floors), 3)
    out_nav = nav_path.with_name(f'{area}.moved.json')
    out_nav.write_text(json.dumps(nav, separators=(',', ':')))
    out = dict(version=2, area=area,
               zones=[dict(zone=z['zone'], kind=z['kind'], reason=z['reason'], moved=z['moved'], ramp=z['ramp'], **z['extra'])
                      for z in zones],
               moved=sorted(r for z in zones for r in z['moved']), ramp=sorted(r for z in zones for r in z['ramp']),
               corner_deltas=corner,
               ceiling_deltas={r: ds for z in zones for r, ds in z.get('ceiling', z['corner']).items()},
               corner_quads={str(r): [[round(v, 3) for v in p] for p in quad[r]] for r in corner},
               native_floors={str(r): list(regs[r]['floor_corners']) for r in corner},
               native_ceilings={str(r): list(regs[r]['ceiling_corners']) for r in corner},
               faces_changed=changed,
               inputs=dict(pack=sha(pack_dir / 'area.json'), nav=sha(nav_path), geometry=sha(maps / area / 'geometry/geometry.json')),
               outputs=dict(pack=sha(out_pack), nav=sha(out_nav)))
    if wide:
        # Height-boundary packet keys of walls this move changed: moved key -> original key (height_boundary_collision).
        out['key_moves'] = key_moves
        # Old saves without a region (L10 has no region collision): carried only when the feet stand on the region's
        # original floor and below the lowest floor of any other region over it in plan (the yard over the tomb).
        out['carry_bands'] = {str(r): carry_band(r, regs, quad, nav_rows, set(corner)) for r in corner}
    spec_path = root / f'scripts/lol2/geometry_moves/{area}.json'
    spec_path.parent.mkdir(parents=True, exist_ok=True)
    spec_path.write_text(json.dumps(out, indent=1))
    print(area, 'zones', [z['zone'] for z in zones], 'moved', len(out['moved']), 'ramp', len(out['ramp']), 'faces changed', changed,
          '->', out_pack.name, out_nav.name)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--maps', type=Path, default=MAPS)
    ap.add_argument('--root', type=Path, default=ROOT)
    ap.add_argument('--area', action='append', choices=sorted(MOVES))
    args = ap.parse_args()
    for area in args.area or sorted(MOVES):
        build(area, args.maps, args.root)


if __name__ == '__main__':
    main()
