#!/usr/bin/env python3
"""Headless walker waypoints from L8 source nav portals, excluding native bit0 regions.
Live collision/creature traversal must still be tested; graph connectivity is not proof.
Run from the repository root after staging L8 nav/blocker packs.
"""
import json,collections
from pathlib import Path
root=Path('assets/lol2/generated');d=json.loads((root/'creature_nav/L8_SJ.json').read_text());rs=d['regions'];blocked=set(map(int,json.loads((root/'region_blockers/L8_SJ.json').read_text())['blocked_regions']))
def route(start,end):
 q=collections.deque([start]);prev={start:None}
 while q:
  a=q.popleft()
  if a==end:break
  for e in rs[a][3]:
   b=int(e[0])
   if b in prev or b in blocked or abs(rs[a][1]-rs[b][1])>18:continue
   prev[b]=(a,e);q.append(b)
 assert end in prev,'no walking route'
 points=[];b=end
 while b!=start:
  a,e=prev[b];points.append([e[1],e[2]]);b=a
 return list(reversed(points))
result = {'source_sha256':d['source_sha256'], 'scope':'Native nav portal centres; headless walking fixture, not original player trajectory',
 'temple':route(2359,1513)[3:]+[[758,2046]], 'village':route(1513,1716)+[[676,-4541]], 'departure':route(1716,908)+[[4026.5,-2667.25]]}
# Walk around live creatures54/55/58 beside the portal centres; no world mutation.
result['village'][49:51] = [[500,-3250],[450,-3370],[450,-3500]]
result['village'][53:53] = [[380,-3630],[380,-3750]]
result['scope'] += '; authored walking detour around creatures54/55/58'
Path('tests/fixtures/l8_first_departure_walk.json').write_text(json.dumps(result,indent=1)+'\n')
print('L8 route waypoints',len(result['temple']),len(result['village']))
