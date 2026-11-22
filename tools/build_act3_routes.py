#!/usr/bin/env python3
"""Walk routes over a level's creature nav (assets/lol2/generated/creature_nav/<AREA>.json: rows [polygon(x,z), floor,
ceiling, edges[(neighbour, mx, mz)]]) between the points a player must reach (BJ10: the Act 3 levels L17/L19/L20, whose
per-step tests placed Luther at each host anchor). Breadth-first over the stored edges plus adjacency rebuilt from the polygons (shared edges, floors within 48), skipping region_blockers; the route is
the chain of crossed-edge midpoints plus the goal. Regions are matched in the Godot x/z plane (nav polygons are stored so).

  python3 tools/build_act3_routes.py AREA x0,z0 x1,z1 [x2,z2 ...]      # print the route legs as JSON
  python3 tools/build_act3_routes.py AREA --json OUT.json x0,z0 x1,z1  # write {"legs": [{"from","to","regions","points"}]}
  python3 tools/build_act3_routes.py AREA --min-width 36 ...           # only through edges a 30-wide body fits

A leg with no nav path prints "NO PATH" with the two regions: that is a map finding (a missing link), not a route.
"""
import argparse, json, sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def inside(poly, x, z):
    ok = False
    n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]
        x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / ((z2 - z1) or 1e-9) + x1:
            ok = not ok
    return ok


def region_at(nav, x, z, floor_hint=None):
    hits = [i for i, r in enumerate(nav) if r[0] and inside(r[0], x, z)]
    if not hits:
        return -1
    if floor_hint is None or len(hits) == 1:
        return hits[0]
    return min(hits, key=lambda i: abs(float(nav[i][1]) - floor_hint))


STEP = 48.0      # floors this far apart still join (stairs and ramps); more is a drop or a pile
CELL = 256.0
TOUCH = 2.0      # shared-edge tolerance in units
MIN_SHARED = 8.0 # a shared edge this long counts as a doorway


def _shared_edge(pa, pb, width=False):
    """Midpoint of a collinear overlapping edge of the two polygons, or None (width=True: the overlap's length, 0 if none)."""
    for i in range(len(pa)):
        a1 = pa[i]; a2 = pa[(i + 1) % len(pa)]
        dx = a2[0] - a1[0]; dz = a2[1] - a1[1]
        ln = (dx * dx + dz * dz) ** 0.5
        if ln < 1e-6:
            continue
        ux, uz = dx / ln, dz / ln
        for j in range(len(pb)):
            b1 = pb[j]; b2 = pb[(j + 1) % len(pb)]
            # both ends of B's edge on A's line
            d1 = abs((b1[0] - a1[0]) * uz - (b1[1] - a1[1]) * ux)
            d2 = abs((b2[0] - a1[0]) * uz - (b2[1] - a1[1]) * ux)
            if d1 > TOUCH or d2 > TOUCH:
                continue
            t1 = (b1[0] - a1[0]) * ux + (b1[1] - a1[1]) * uz
            t2 = (b2[0] - a1[0]) * ux + (b2[1] - a1[1]) * uz
            lo = max(0.0, min(t1, t2)); hi = min(ln, max(t1, t2))
            if hi - lo >= MIN_SHARED:
                m = (lo + hi) / 2.0
                return (hi - lo) if width else (a1[0] + ux * m, a1[1] + uz * m)
    return 0.0 if width else None


def geometry_links(nav):
    """Adjacency rebuilt from the polygons: regions sharing an edge with floors within STEP. The stored edges are kept too."""
    links = {}
    grid = {}
    boxes = {}
    for i, r in enumerate(nav):
        if not r[0]:
            continue
        xs = [p[0] for p in r[0]]; zs = [p[1] for p in r[0]]
        boxes[i] = (min(xs), min(zs), max(xs), max(zs))
        for gx in range(int(boxes[i][0] // CELL), int(boxes[i][2] // CELL) + 1):
            for gz in range(int(boxes[i][1] // CELL), int(boxes[i][3] // CELL) + 1):
                grid.setdefault((gx, gz), []).append(i)
        links[i] = {}
        for e in r[3]:
            if isinstance(e, list) and e and 0 <= int(e[0]) < len(nav):
                other = int(e[0])
                # A stored edge over a floor step a body cannot climb (or a drop that hurts) is not a player's way.
                if nav[other][0] and abs(float(r[1]) - float(nav[other][1])) > STEP:
                    continue
                links[i][other] = (float(e[1]), float(e[2]))
    seen = set()
    for cell, ids in grid.items():
        for x in range(len(ids)):
            for y in range(x + 1, len(ids)):
                i, j = ids[x], ids[y]
                if (i, j) in seen:
                    continue
                seen.add((i, j))
                bi, bj = boxes[i], boxes[j]
                if bi[0] > bj[2] + TOUCH or bj[0] > bi[2] + TOUCH or bi[1] > bj[3] + TOUCH or bj[1] > bi[3] + TOUCH:
                    continue
                if abs(float(nav[i][1]) - float(nav[j][1])) > STEP:
                    continue
                if j in links[i] and i in links[j]:
                    continue
                m = _shared_edge(nav[i][0], nav[j][0])
                if m is None:
                    continue
                links[i].setdefault(j, m)
                links[j].setdefault(i, m)
    return links


def route(nav, blocked, start, goal, floor_start=None, floor_goal=None, links=None):
    a = region_at(nav, start[0], start[1], floor_start)
    b = region_at(nav, goal[0], goal[1], floor_goal)
    if a < 0 or b < 0:
        return {"error": "point outside the nav", "from": list(start), "to": list(goal), "from_region": a, "to_region": b}
    if links is None:
        links = geometry_links(nav)
    prev = {a: None}
    via = {}
    queue = deque([a])
    while queue:
        cur = queue.popleft()
        if cur == b:
            break
        for nxt, mid in links.get(cur, {}).items():
            if nxt in prev or nxt in blocked or not nav[nxt][0]:
                continue
            prev[nxt] = cur
            via[nxt] = mid
            queue.append(nxt)
    if b not in prev:
        return {"error": "NO PATH", "from": list(start), "to": list(goal), "from_region": a, "to_region": b}
    regions = []
    points = []
    cur = b
    while cur is not None:
        regions.append(cur)
        if cur in via:
            points.append(list(via[cur]))
        cur = prev[cur]
    regions.reverse()
    points.reverse()
    points.append([float(goal[0]), float(goal[1])])
    return {"from": list(start), "to": list(goal), "from_region": a, "to_region": b, "regions": regions, "points": points}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("area")
    ap.add_argument("points", nargs="+", help="x,z[,floor] pairs in walking order")
    ap.add_argument("--json", type=Path)
    ap.add_argument("--min-width", type=float, default=0.0, help="leave out links whose shared edge is narrower than this (BJ12: the Human body is 30 wide; a 24-wide native edge at L8 2293/2376 stops it)")
    args = ap.parse_args()
    nav = json.loads((ROOT / f"assets/lol2/generated/creature_nav/{args.area}.json").read_text())["regions"]
    blocked = set()
    bl = ROOT / f"assets/lol2/generated/region_blockers/{args.area}.json"
    if bl.exists():
        blocked = set(int(r) for r in json.loads(bl.read_text()).get("blocked_regions", []))
    pts = []
    for raw in args.points:
        parts = [float(v) for v in raw.split(",")]
        pts.append((parts[0], parts[1], parts[2] if len(parts) > 2 else None))
    legs = []
    bad = 0
    links = geometry_links(nav)
    if args.min_width > 0:
        for i in links:
            for j in [j for j in links[i] if 0 < _shared_edge(nav[i][0], nav[j][0], True) < args.min_width]:
                del links[i][j]
    for i in range(len(pts) - 1):
        leg = route(nav, blocked, pts[i][:2], pts[i + 1][:2], pts[i][2], pts[i + 1][2], links)
        legs.append(leg)
        if "error" in leg:
            bad += 1
            print(f"leg {i}: {leg['error']} from {pts[i][:2]} (region {leg['from_region']}) to {pts[i + 1][:2]} (region {leg['to_region']})")
        else:
            print(f"leg {i}: {len(leg['regions'])} regions, {len(leg['points'])} points, {pts[i][:2]} -> {pts[i + 1][:2]}")
    if args.json:
        args.json.write_text(json.dumps({"area": args.area, "legs": legs}, indent=None))
        print("wrote", args.json)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
