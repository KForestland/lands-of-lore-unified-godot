#!/usr/bin/env python3
"""Floor adjacency routes from earned L7 entry region 47 to slide approach floors."""
import json, math
from pathlib import Path
from collections import defaultdict,deque
ROOT=Path(__file__).resolve().parents[1]
def main():
 a=json.loads((ROOT/'assets/lol2/generated/dark_halls/area.json').read_text())
 floors={int(f['region']):f['points'] for f in a['faces'] if f['kind']=='floor' and f.get('region') is not None}
 edges=defaultdict(list); es={}; h={}; center={}
 for r,pts in floors.items():
  h[r]=max(p[1] for p in pts);center[r]=[sum(p[i] for p in pts)/len(pts) for i in [0,2]]
  es[r]=[]
  for i,p in enumerate(pts):
   q=pts[i-1];e=tuple(sorted(((round(p[0],2),round(p[2],2)),(round(q[0],2),round(q[2],2)))))
   if math.dist(*e)>=24:edges[e].append(r);es[r].append(e)
 prev={47:None};via={};todo=deque([47])
 while todo:
  r=todo.popleft()
  for e in es[r]:
   for s in edges[e]:
    if s in prev or h[s]-h[r]>32:continue
    prev[s]=r;via[s]=[(e[0][i]+e[1][i])/2 for i in range(2)];todo.append(s)
 routes=[]
 for c in json.loads((ROOT/'scripts/lol2/dark_halls_slides_source.json').read_text())['controls']:
  x,y,z=c['center']; candidates=[r for r in prev if abs(h[r]+52-y)<65]
  r=min(candidates,key=lambda r:math.dist(center[r],[x,z]));d=math.dist(center[r],[x,z]);print(c['control'],r,center[r],h[r],d)
  chain=[];s=r
  while prev[s] is not None:chain.append(via[s]);s=prev[s]
  routes.append(dict(control=c['control'],points=list(reversed(chain))+[center[r]],region=r,distance=d))
 (ROOT/'tests/dark_halls_slides_walk.json').write_text(json.dumps(dict(routes=routes),indent=1)+'\n')
 print('PASS built slide floor routes; runtime walk still required')
if __name__=='__main__':main()
