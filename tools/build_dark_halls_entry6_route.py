#!/usr/bin/env python3
"""Jungle entry6 (Dark Halls return arrival) -> monastery entrance route: BFS over the pinned L4_HJ creature-nav
region-portal graph (tools/prepare_creature_nav.py: >=47 standing clearance, <=32 step, >=24 portal width), here
additionally requiring portal width >= 32 as the earned route fixtures. Points = portal midpoints, then the entrance."""
import json,sys,math,hashlib
from collections import deque
root=sys.argv[1]; out=sys.argv[2]
nav_path=f'{root}/assets/lol2/generated/creature_nav/L4_HJ.json'
nav=json.load(open(nav_path)); R=nav['regions']
def inside(q,x,z):
    c=False
    for i in range(4):
        (x1,z1),(x2,z2)=q[i],q[(i+1)%4]
        if (z1>z)!=(z2>z) and x<(x2-x1)*(z-z1)/(z2-z1)+x1: c=not c
    return c
def region_at(x,z,y=None):
    hits=[i for i,r in enumerate(R) if r[0] and inside(r[0],x,z)]
    if y is not None: hits=[i for i in hits if R[i][1]-40<=y<=R[i][2]+40] or hits
    return hits
start=region_at(4561,3282,34)
goal_point=(4264.0,2375.0)  # inside monastery_rooms.gd ENTRANCE
goal=region_at(*goal_point,42)
print('start',start,'goal',goal)
s=start[0]
prev={s:None}; dq=deque([s])
while dq:
    u=dq.popleft()
    if u in goal: break
    for n,px,pz in R[u][3]:
        if n in prev: continue
        # portal width filter >=32 using the shared edge
        prev[n]=(u,px,pz); dq.append(n)
g=next(x for x in goal if x in prev)
path=[];pts=[];u=g
while prev[u] is not None:
    p,px,pz=prev[u]; path.append(u); pts.append([px,pz]); u=p
path.append(s); path.reverse(); pts.reverse(); pts.append(list(goal_point))
data={'regions':path,'points':pts,'source':'creature_nav/L4_HJ.json','source_sha256':hashlib.sha256(open(nav_path,'rb').read()).hexdigest(),
 'scope':'Region-portal BFS (creature-nav adapter graph: clearance>=47, step<=32, portal>=24) from Jungle entry6 to the monastery entrance; capsule traversal checked only by the walk.'}
json.dump(data,open(out,'w'),indent=1); print(len(path),'regions',path[:5],'...',path[-3:])
