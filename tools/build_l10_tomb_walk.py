#!/usr/bin/env python3
"""Build source-nav waypoints from the earned STORY-006 checkpoint; geometry is verified by the live walker."""
import json,collections
from pathlib import Path
p=json.load(open('tmp/l10_gate_earned_save.json'))
d=json.load(open('assets/lol2/generated/creature_nav/L10_DC.json'));r=d['regions']
def inside(p,q):
 if len(q)<3:return False
 signs=[(b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0]) for a,b in zip(q,q[1:]+q[:1])];return min(signs)>=0 or max(signs)<=0
def region(pt,h):return min((i for i,x in enumerate(r) if inside(pt,x[0])),key=lambda i:abs(r[i][1]-h))
blocked=set(json.load(open('assets/lol2/generated/region_blockers/L10_DC.json'))['blocked_regions'])
def route(start,end):
 q=collections.deque([start]);prev={start:None}
 while q:
  a=q.popleft()
  if a==end:break
  for e in r[a][3]:
   b=int(e[0])
   if b in prev or b in blocked or abs(r[a][1]-r[b][1])>18:continue
   prev[b]=(a,e);q.append(b)
 if end not in prev: print('NO ROUTE',start,end,len(prev));return []
 pts=[];b=end
 while b!=start:
  a,e=prev[b];pts.append([e[1],e[2]]);b=a
 return pts[::-1]
pos=p['player']['position'];start=region((pos[0],pos[2]),pos[1]-32)
a=region((1078,-3530),-157);b=region((1152,-3560),-157);c=region((1037,-4270),0)
print('regions',start,a,b,c)
out={'source_sha256':d['source_sha256'],'pickup':route(start,a)+[[1078,-3480]],'charger':route(a,b)+[[1152,-3560]],'door':route(b,c)+[[1037,-4270]]}
print({k:len(v) for k,v in out.items()});Path('tests/fixtures/l10_tomb_walk.json').write_text(json.dumps(out,indent=1)+'\n')
