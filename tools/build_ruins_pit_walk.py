#!/usr/bin/env python3
"""Waypoints only; the earned headless walker must prove collision and transitions."""
import collections
import json
import math
from pathlib import Path


def inside(point, polygon):
    signs = [(b[0]-a[0])*(point[1]-a[1])-(b[1]-a[1])*(point[0]-a[0])
             for a, b in zip(polygon, polygon[1:]+polygon[:1])]
    return len(signs) >= 3 and (min(signs) >= 0 or max(signs) <= 0)


def route(area, position, goal):
    data = json.loads(Path(f'assets/lol2/generated/creature_nav/{area}.json').read_text())
    regions = data['regions']
    blocked = set(json.loads(Path(f'assets/lol2/generated/region_blockers/{area}.json').read_text())['blocked_regions'])
    def center(i):
        return [sum(p[k] for p in regions[i][0])/len(regions[i][0]) for k in range(2)]
    start = min((i for i, r in enumerate(regions) if inside([position[0], position[2]], r[0])),
                key=lambda i: abs(regions[i][1]-(position[1]-32)))
    queue = collections.deque([start])
    previous = {start: None}
    while queue:
        a = queue.popleft()
        for edge in regions[a][3]:
            b = int(edge[0])
            if b in previous or b in blocked or abs(regions[a][1]-regions[b][1]) > 18:
                continue
            previous[b] = (a, edge)
            queue.append(b)
    # A falling pit need not connect to the ordinary walking graph. Stop at its
    # nearest reachable rim; no missing edge or gameplay state is invented.
    end = goal if goal in previous else min(previous, key=lambda i: math.dist(center(i), center(goal)))
    b = end
    points = [center(end)]
    while b != start:
        a, edge = previous[b]
        points.append([edge[1], edge[2]])
        b = a
    return dict(source_sha256=data['source_sha256'], start_region=start,
                goal_region=goal, reached_region=end, points=points[::-1], pit=center(goal))


save = json.loads(Path('tmp/l10_gold_earned_save.json').read_text())
result = dict(cemetery=route('L10_DC', save['player']['position'], 0),
              jungle=route('L8_SJ', [3972, 48, -2482], 427))
Path('tests/fixtures/ruins_pit_earned_walk.json').write_text(json.dumps(result, indent=1)+'\n')
