#!/usr/bin/env python3
"""Waypoints for tests/dark_halls_slice_test.gd: Dark Halls arrival region 47 -> slice exit region 1617.

Breadth-first over floor regions sharing an edge at least 20 units long, climbing at most 32 (any drop allowed);
waypoints are the midpoints of the longest shared edges. Reads the staged pack, writes tests/dark_halls_walk_path.json.
"""
import json, math
from collections import deque, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    area = json.loads((ROOT / 'assets/lol2/generated/dark_halls/area.json').read_text())
    floors, heights = {}, {}
    for f in area['faces']:
        if f['kind'] == 'floor' and f.get('region') is not None:
            floors[f['region']] = [(p[0], p[2]) for p in f['points']]
            heights[f['region']] = max(p[1] for p in f['points'])
    key = lambda p: (round(p[0]), round(p[1]))
    edges = {r: {frozenset((key(p[i]), key(p[i - 1]))) for i in range(len(p))} for r, p in floors.items()}
    owners = defaultdict(list)
    for r, es in edges.items():
        for e in es: owners[e].append(r)
    length = lambda e: math.dist(*list(e))
    prev, queue = {47: None}, deque([47])
    while queue:
        r = queue.popleft()
        for e in edges[r]:
            for s in owners[e]:
                if s in prev or heights[s] - heights[r] > 32 or max(length(x) for x in edges[r] & edges[s]) < 20: continue
                prev[s] = r; queue.append(s)
    assert 1617 in prev, 'slice exit unreachable'
    path, r = [], 1617
    while r is not None: path.append(r); r = prev[r]
    path.reverse()
    points = []
    for a, b in zip(path, path[1:]):
        (x1, z1), (x2, z2) = list(max(edges[a] & edges[b], key=length))
        points.append([round((x1 + x2) / 2, 1), round((z1 + z2) / 2, 1)])
    c = floors[1617]; points.append([round(sum(p[0] for p in c) / len(c), 1), round(sum(p[1] for p in c) / len(c), 1)])
    (ROOT / 'tests/dark_halls_walk_path.json').write_text(json.dumps(dict(regions=path, points=points)) + '\n')
    print(f'PASS {len(path)} regions, {len(points)} waypoints')


if __name__ == '__main__':
    main()
