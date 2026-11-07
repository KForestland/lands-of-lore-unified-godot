#!/usr/bin/env python3
"""Clip redundant lower ceiling collision where the original upper ritual floors already overlap it."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=json.loads((ROOT/'assets/lol2/generated/maps/L14_HT/area.json').read_text())
s=json.loads((ROOT/'docs/l14-priest-ritual-source.json').read_text())
g=next(g for g in s['groups'] if g['group']==14556)
ids={c['target'] for c in g['commands']}
ceil_ids=[163,164,780,781,3236,3237,3238,3239,3240,3241,3242,3243,3244,3245,3246,3247,3248,3253,3419,3420,3421,3422,3425,3427,3429,3431]
def area(poly):return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))/2
# Split a convex polygon by one oriented line. Keep left or right half-plane.
def half(poly,a,b,left):
 out=[]
 def d(p):return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
 for p,q in zip(poly,poly[1:]+poly[:1]):
  dp,dq=d(p),d(q);ip=dp>=-1e-8 if left else dp<=1e-8;iq=dq>=-1e-8 if left else dq<=1e-8
  if ip:out.append(p)
  if ip!=iq and abs(dp-dq)>1e-10:
   t=dp/(dp-dq);out.append([p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])])
 return out if len(out)>=3 and abs(area(out))>1e-6 else []
def subtract(poly,triangle):
 if area(triangle)<0:triangle=list(reversed(triangle))
 out=[];remaining=poly
 for a,b in zip(triangle,triangle[1:]+triangle[:1]):
  if not remaining:break
  outside=half(remaining,a,b,False)
  if outside:out.append(outside)
  remaining=half(remaining,a,b,True)
 return out
clips=[]
for f in p['faces']:
 if f.get('kind')=='floor' and f.get('region') in ids:
  for tri in [(0,1,2),(0,2,3)]:clips.append([[f['points'][i][0],f['points'][i][2]] for i in tri])
points=[];removed=0
for f in p['faces']:
 if f.get('kind')!='ceiling' or f.get('region') not in ceil_ids:continue
 assert all(q[1]==20 for q in f['points'])
 for tri in [(0,1,2),(0,2,3)]:
  poly=[[f['points'][i][0],f['points'][i][2]] for i in tri];pieces=[poly]
  for clip in clips:pieces=[part for piece in pieces for part in subtract(piece,clip)]
  removed+=abs(area(poly))-sum(abs(area(a)) for a in pieces)
  for piece in pieces:
   for i in range(1,len(piece)-1):points.extend([[q[0],20,q[1]] for q in [piece[0],piece[i],piece[i+1]]])
assert removed>0
out={'source_sha256':s['source_sha256'],'ceiling_regions':ceil_ids,'floor_regions':sorted(ids),'removed_xz_area':removed,'points':points}
(ROOT/'scripts/lol2/l14_ritual_ceiling_collision.json').write_text(json.dumps(out,separators=(',',':'))+'\n')
print('clipped only upper-floor overlap:',round(removed,2),'area;',len(points)//3,'remaining original-height triangles')
