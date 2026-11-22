#!/usr/bin/env python3
"""Earned-approach routes using original region neighbor links, not whole-edge equality.

Some L7 neighbors meet along partial edges: an exported-floor whole-edge graph falsely disconnects controls1041/1013.
Routes are plans; active-runtime input walks must prove clearance, gates and combat.
"""
import argparse,json,math
from pathlib import Path
from collections import deque
import prepare_dark_halls_routes as Routes
from lol2_geometry_format import slope_corners
ROOT=Path(__file__).resolve().parents[1]
def shared_portal(v, w, polygon):
 """Clip a source neighbor edge to the destination floor's actual opening.

 Native neighbor links may occupy a partial edge (179 -> 180: 61 of 133 units).
 A full-edge midpoint can send a Human into the jamb instead of through it.
 """
 start=[v[0]/65536,-v[1]/65536];end=[w[0]/65536,-w[1]/65536]
 delta=[end[i]-start[i] for i in range(2)]
 center=[sum(p[i] for p in polygon)/len(polygon) for i in [0,2]]
 lo,hi=0.0,1.0
 for i,a in enumerate(polygon):
  b=polygon[(i+1)%len(polygon)];edge=[b[0]-a[0],b[2]-a[2]]
  cross=lambda p:edge[0]*(p[1]-a[2])-edge[1]*(p[0]-a[0])
  sign=1 if cross(center)>=0 else -1
  initial=sign*cross(start);change=sign*(edge[0]*delta[1]-edge[1]*delta[0])
  if abs(change)<1e-9:
   if initial < -0.01:return None
  elif change>0:lo=max(lo,(-0.01-initial)/change)
  else:hi=min(hi,(-0.01-initial)/change)
 if lo>hi or math.dist(start,end)*(hi-lo)<30:return None
 return [start[i]+delta[i]*(lo+hi)/2 for i in range(2)]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);args=p.parse_args()
 h=Routes.Hive.load(args.game,'dark_halls');rec=h['records'];vs=h['vertices'];a=json.loads((ROOT/'assets/lol2/generated/dark_halls/area.json').read_text())
 floors={f['region']:f for f in a['faces'] if f['kind']=='floor'}
 centers={r:[sum(v[i] for v in f['points'])/4 for i in [0,2]] for r,f in floors.items()}
 height={r:max(slope_corners(rec,r)) for r in floors};prev={47:None};via={};todo=deque([47])
 while todo:
  r=todo.popleft()
  for edge,s in enumerate(rec[r][2:6]):
   if s in prev or s not in floors or height[s]-height[r]>32:continue
   v,w=vs[rec[r][6+edge]],vs[rec[r][6+(edge+1)%4]]
   portal=shared_portal(v,w,floors[s]["points"])
   if portal is None:continue  # Current Human capsule diameter, not a game-rule change.
   via[s]=portal;prev[s]=r;todo.append(s)
 routes=[]
 for family in ['slides','bookcases']:
  for c in json.loads((ROOT/f'scripts/lol2/dark_halls_{family}_source.json').read_text())['controls']:
   x,y,z=c['center'];candidates=[r for r in prev if abs(height[r]+42-y)<50]
   r=min(candidates,key=lambda r:math.dist(centers[r],[x,z]));goal=centers[r]
   if family=='slides':
    faces=[f for f in a['faces'] if f.get('placement')==f"static_{c['control']}"]
    spans=[max(v[i] for f in faces for v in f['points'])-min(v[i] for f in faces for v in f['points']) for i in [0,2]]
    axis=0 if spans[0]<spans[1] else 1
    def inside(point,poly):
     turns=[]
     for i,v in enumerate(poly):
      w=poly[(i+1)%len(poly)]
      turns.append((w[0]-v[0])*(point[1]-v[2])-(w[2]-v[2])*(point[0]-v[0]))
     return all(t>=-0.01 for t in turns) or all(t<=0.01 for t in turns)
    approaches=[]
    for sign in [-1,1]:
     point=[x,z];point[axis]+=sign*60  # A route-planning stand-off inside existing110 use reach.
     for region in candidates:
      if inside(point,floors[region]['points']):
       depth=0;n=region
       while prev[n] is not None:depth+=1;n=prev[n]
       approaches.append((depth,abs(height[region]+42-y),region,point))
    assert approaches, ('No source-floor approach for slide',c['control'])
    _,_,r,goal=min(approaches)
   chain=[];s=r
   while prev[s] is not None:chain.append(s);s=prev[s]
   chain.reverse();points=[via[s] for s in chain]+[goal]
   routes.append(dict(family=family,control=c['control'],points=points,regions=chain+[r],region=r,distance=math.dist(goal,[x,z])))
   print(family,c['control'],'region',r,'distance',round(routes[-1]['distance'],1),'waypoints',len(points))
 (ROOT/'tests/dark_halls_objects_walk.json').write_text(json.dumps(dict(routes=routes),indent=1)+'\n')
 print('PASS source neighbor routes staged; runtime earned proof still required')
if __name__=='__main__':main()
