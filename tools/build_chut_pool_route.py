#!/usr/bin/env python3
"""CHUT exit placement (-1769,-5464, region3791) -> watergate pool route for the chief-hut walk.

The chief's-hut room returns Luther outside the shut inner gate (docs/jungle-chut-room.md); the longplay reaches the
pool from the jungle (67:08-67:48). The earlier earned route inner_gate_to_pool (tests/fixtures/chief_hut_walk_routes.json)
already walked from the yard back out through region3791, the village and its open gate to the pool. This route is that
same walked route from its first region3791 point on, preceded by the CHUT placement. (A plain region-portal BFS put a
waypoint on the open village gate leaf 78.)"""
import json,sys
root=sys.argv[1]; out=sys.argv[2]
base=json.load(open(f'{root}/tests/fixtures/chief_hut_walk_routes.json'))['inner_gate_to_pool']
cut=base['regions'].index(3791)
data={'chut_to_pool':{'regions':[3791]+base['regions'][cut:],'points':[[-1769.0,-5464.0]]+base['points'][cut:],
 'source':'tests/fixtures/chief_hut_walk_routes.json inner_gate_to_pool from its first region3791 point',
 'scope':'CHUT exit placement, then the earned inner_gate_to_pool route from region3791 (village, open village gate, jungle, watergate pool).'}}
json.dump(data,open(out,'w'),indent=1); print(len(data['chut_to_pool']['points']),'points from base index',cut)
