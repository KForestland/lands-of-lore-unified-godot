#!/usr/bin/env python3
import sys,json,math
from pathlib import Path
from collections import deque
import argparse
p=argparse.ArgumentParser(description='Plan BH04-BH08 source-neighbor approaches; runtime input walks prove clearance.')
p.add_argument('--game',type=Path,required=True);args=p.parse_args()
r=Path(__file__).resolve().parents[1];sys.path.insert(0,str(r/'tools'))
from build_dark_halls_objects_walk import shared_portal
import prepare_dark_halls_routes as Routes
from lol2_geometry_format import slope_corners
h=Routes.Hive.load(args.game,'dark_halls');rec=h['records'];vs=h['vertices'];a=json.loads((r/'assets/lol2/generated/dark_halls/area.json').read_text())
floors={f['region']:f for f in a['faces'] if f['kind']=='floor'}
centers={k:[sum(v[i] for v in f['points'])/4 for i in [0,2]] for k,f in floors.items()};height={k:max(slope_corners(rec,k)) for k in floors}
prev={47:None};via={};todo=deque([47])
while todo:
 k=todo.popleft()
 for edge,s in enumerate(rec[k][2:6]):
  if s in prev or s not in floors or height[s]-height[k]>32:continue
  v,w=vs[rec[k][6+edge]],vs[rec[k][6+(edge+1)%4]];portal=shared_portal(v,w,floors[s]['points'])
  if portal is None:continue
  prev[s]=k;via[s]=portal;todo.append(s)
# Targets stay on the near side of each puzzle, using the actual floor polygons.
goals={'iron':[-1243,750,-475],'escape':[-1277,750,20],'atrium':[1871,400,-3520],'orb':[-1470,750,-180],'bash':[-2682,85,-2459]}
routes={}
for name,(x,y,z) in goals.items():
 candidates=[k for k in prev if abs(height[k]-y)<35]; k=min(candidates,key=lambda k:math.dist(centers[k],[x,z]));chain=[];n=k
 while prev[n] is not None:chain.append(n);n=prev[n]
 chain.reverse();goal=centers[k]
 # These exact stands are inside their selected floor quads; runtime proof still required.
 def inside(p,poly):
  turns=[(b[0]-a[0])*(p[1]-a[2])-(b[2]-a[2])*(p[0]-a[0]) for a,b in zip(poly,poly[1:]+poly[:1])];return min(turns)>=-0.01 or max(turns)<=0.01
 exact=[k for k in candidates if inside([x,z],floors[k]['points'])]
 if exact:
  k=min(exact,key=lambda k:abs(height[k]-y));chain=[];n=k
  while prev[n] is not None:chain.append(n);n=prev[n]
  chain.reverse();goal=[x,z]
 routes[name]=dict(region=k,regions=chain,points=[via[n] for n in chain]+[goal],target=[x,y,z]);print(name,k,len(chain)+1,goal)
(r/'tests/dark_halls_puzzles_walk.json').write_text(json.dumps(routes,indent=1)+'\n')
