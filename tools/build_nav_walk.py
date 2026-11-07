#!/usr/bin/env python3
"""Plan a test walk over a creature-nav region graph (assets/lol2/generated/creature_nav/AREA.json).

Breadth-first over neighbours, skipping native bit0 blocked regions (region_blockers/AREA.json) and floor steps higher
than --step. Waypoints are the shared-edge midpoints, then the goal. Output: JSON list of [x, z] (Godot). A planning
aid for earned walk tests only; the test itself still walks with production movement.
"""
import argparse, json, collections
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def inside(poly, x, z):
    c = False
    for i in range(len(poly)):
        x1, z1 = poly[i]; x2, z2 = poly[i - 1]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1: c = not c
    return c

def main():
    a = argparse.ArgumentParser()
    a.add_argument("--area", required=True); a.add_argument("--start", nargs=2, type=float, required=True)
    a.add_argument("--goal", nargs=2, type=float, required=True); a.add_argument("--step", type=float, default=30.0)
    a.add_argument("--open", nargs="*", type=int, default=[]); a.add_argument("--out")
    a.add_argument("--open-movables", nargs="*", type=int, default=[])
    o = a.parse_args()
    nav = json.loads((ROOT / f"assets/lol2/generated/creature_nav/{o.area}.json").read_text())["regions"]
    bl = ROOT / f"assets/lol2/generated/region_blockers/{o.area}.json"
    blocked = set(json.loads(bl.read_text())["blocked_regions"]) if bl.exists() else set()
    blocked -= set(o.open)
    # Closed movables (gates, panels) are walls for the walk: skip any portal whose midpoint lies within 14 units of a
    # movable face footprint (vertical faces only). --open-movables lists ids already opened in the scenario.
    area = json.loads((ROOT / f"assets/lol2/generated/maps/{o.area}/area.json").read_text())
    segs = []
    for f in area["faces"]:
        if f.get("kind") != "movable" or int(f.get("source_index", -1)) in o.open_movables: continue
        p = f["points"]
        if max(q[1] for q in p) - min(q[1] for q in p) < 20: continue
        xs = [q[0] for q in p]; zs = [q[2] for q in p]
        segs.append((min(xs) - 14, max(xs) + 14, min(zs) - 14, max(zs) + 14))
    def walled(x, z): return any(a <= x <= b and c <= z <= d for a, b, c, d in segs)
    def region(x, z):
        hits = [i for i, r in enumerate(nav) if inside(r[0], x, z)]
        return hits[0] if hits else None
    s, g = region(*o.start), region(*o.goal)
    if s is None or g is None: raise SystemExit(f"start/goal outside nav: {s} {g}")
    prev = {s: None}; q = collections.deque([s])
    while q:
        r = q.popleft()
        if r == g: break
        for n, mx, mz in nav[r][3]:
            n = int(n)
            if n >= len(nav) or n in prev or n in blocked: continue
            if abs(float(nav[n][1]) - float(nav[r][1])) > o.step: continue
            if walled(float(mx), float(mz)): continue
            prev[n] = (r, mx, mz); q.append(n)
    if g not in prev: raise SystemExit("no route")
    pts = []; r = g
    while prev[r] is not None:
        p, mx, mz = prev[r]; pts.append([round(mx, 1), round(mz, 1)]); r = p
    pts.reverse(); pts.append([o.goal[0], o.goal[1]])
    print(f"regions {s}->{g}, {len(pts)} waypoints", flush=True)
    if o.out: Path(o.out).write_text(json.dumps(pts))
    else: print(json.dumps(pts))
main()
