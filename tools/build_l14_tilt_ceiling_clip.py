#!/usr/bin/env python3
"""Clip stacked lower-ceiling fragments only beneath the original middle-trial route."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=json.loads((ROOT/'assets/lol2/generated/maps/L14_HT/area.json').read_text())
ids={1461,1462,1463,1464,2135,2131,2128,2132,2133,2134,2682,2683,2684,2291,2290}
def area(poly):return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))/2
def half(poly,a,b,left):
 out=[]
 def d(p):return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
 for p,q in zip(poly,poly[1:]+poly[:1]):
  dp,dq=d(p),d(q);ip=dp>=-1e-8 if left else dp<=1e-8;iq=dq>=-1e-8 if left else dq<=1e-8
  if ip:out.append(p)
  if ip!=iq and abs(dp-dq)>1e-10:
   t=dp/(dp-dq);out.append([p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])])
 return out if len(out)>=3 and abs(area(out))>1e-6 else []
def subtract(poly,clip):
 if area(clip)<0:clip=list(reversed(clip))
 out=[];remaining=poly
 for a,b in zip(clip,clip[1:]+clip[:1]):
  if abs(a[0]-b[0])+abs(a[1]-b[1])<1e-8:continue
  if not remaining:break
  outside=half(remaining,a,b,False)
  if outside:out.append(outside)
  remaining=half(remaining,a,b,True)
 return out
clips=[[[v[0],v[2]] for v in f['points']] for f in p['faces'] if f['kind']=='floor' and f.get('region') in ids]
faces=[];selected=[];removed=0
for face in p['faces']:
 if face['kind']!='ceiling' or face.get('region') in ids or max(v[1] for v in face['points'])<40 or min(v[1] for v in face['points'])>=340:continue
 remaining_faces=[];lost=0
 for indices in ((0,1,2),(0,2,3)):
  tri=[face['points'][i] for i in indices];uv=[face['uv'][i] for i in indices];poly=[[v[0],v[2]] for v in tri]
  if abs(area(poly))<1e-6:continue
  parts=[poly]
  for clip in clips:parts=[part for piece in parts for part in subtract(piece,clip)]
  lost+=abs(area(poly))-sum(abs(area(part)) for part in parts)
  a,b,c=poly;det=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
  def interpolate(q):
   u=((q[0]-a[0])*(c[1]-a[1])-(q[1]-a[1])*(c[0]-a[0]))/det
   v=((b[0]-a[0])*(q[1]-a[1])-(b[1]-a[1])*(q[0]-a[0]))/det
   y=tri[0][1]+u*(tri[1][1]-tri[0][1])+v*(tri[2][1]-tri[0][1])
   tex=[uv[0][j]+u*(uv[1][j]-uv[0][j])+v*(uv[2][j]-uv[0][j]) for j in (0,1)]
   return [q[0],y,q[1]],tex
  for part in parts:
   for i in range(1,len(part)-1):
    vertices=[interpolate(q) for q in (part[0],part[i],part[i+1])]
    remaining_faces.append({'region':face['region'],'material':face['material'],'points':[v[0] for v in vertices],'uv':[v[1] for v in vertices]})
 if lost>1e-4:selected.append(face['region']);faces+=remaining_faces;removed+=lost
out={'source_sha256':'c294f9ab142b55c36fff545a1293c419c42353fedefbfe8b77b9c38a2d9a0719','floor_regions':sorted(ids),'ceiling_regions':sorted(set(selected)),'removed_xz_area':removed,'faces':faces}
(ROOT/'scripts/lol2/l14_tilt_ceiling_clip.json').write_text(json.dumps(out,separators=(',',':'))+'\n')
print('Scoped lower ceilings',out['ceiling_regions'],'remaining triangles',len(faces),'clipped area',round(removed,2))
