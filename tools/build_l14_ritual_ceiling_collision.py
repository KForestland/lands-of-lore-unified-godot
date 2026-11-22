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
# Upper way (owner/robot stop 2026-11-13, slab-to-pew): the floor-0 way from the entrance to the slab and on to the pews
# (952 955 954 786 785 848 846 860 858 859 856 | 812 816 814 821 818 820 819 21 22 23 24 1056 1058, all MIX neighbours,
# grok_research/TEMPLE_SLAB_PEW_20261112.md) stands over the lower stair/corridor layer whose ceilings at y 20 fill the
# walker's body space; those ceilings are clipped where an upper-way floor covers them, as the ritual floors already do.
UPPER_WAY=[952,955,954,786,785,848,846,860,858,859,856,812,816,814,821,818,820,819,21,22,23,24,1056,1058]
UPPER_CEILINGS=[3254,3255,3256,3257,3258,3259,3260,3261,3262,3263,3264,3267,3270,3274,3278,3282,3283,3287,3345,3346,3347,3348,3349,3350,3351,3352,3353,3354,3355,3356,3358,3359,3360,3361,3362,3363,3364,3365,3366,3368,3872,3876,3877,3885,3886,3887,3888,3891,3895,3899,3903]
ceil_ids=ceil_ids+[c for c in UPPER_CEILINGS if c not in ceil_ids]
ids=set(ids)|set(UPPER_WAY)
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
# The upper way's lower ceilings collide in the ritual's two-sided body, so they are clipped by EVERY floor that stands
# over them within a body's reach (floor >= -30), not only the listed way (the entrance 951 covers some of them too).
upper_clips=[]
for f in p['faces']:
 if f.get('kind')=='floor' and min(q[1] for q in f['points'])>=-30:
  for tri in [(0,1,2),(0,2,3)]:upper_clips.append([[f['points'][i][0],f['points'][i][2]] for i in tri])
# Doors 92/93 (lead 2026-11-14; owner r19g 14-08-18 walked at feet 20 in front of the closed doors): the other lower
# ceiling 781 (under the hall before the doors) pokes 20 above the floor-0 hall where no listed floor covers it (792
# east of door 92). It is clipped by any floor that stands in the body's space under it (-30 <= floor <= 20). Named:
# the north side (3360) is already in UPPER_CEILINGS; other lower ceilings are left as they were.
HALL_CEILINGS=[781]
hall_clips=[]
for f in p['faces']:
 if f.get('kind')=='floor' and min(q[1] for q in f['points'])>=-30 and max(q[1] for q in f['points'])<=20:
  for tri in [(0,1,2),(0,2,3)]:hall_clips.append([[f['points'][i][0],f['points'][i][2]] for i in tri])
points=[];removed=0
for f in p['faces']:
 if f.get('kind')!='ceiling' or f.get('region') not in ceil_ids:continue
 assert all(q[1]==20 for q in f['points'])
 for tri in [(0,1,2),(0,2,3)]:
  poly=[[f['points'][i][0],f['points'][i][2]] for i in tri];pieces=[poly]
  use=clips
  bx=(min(q[0] for q in poly),max(q[0] for q in poly),min(q[1] for q in poly),max(q[1] for q in poly))
  if f.get('region') in HALL_CEILINGS:
   use=clips+[c for c in hall_clips if not (max(q[0] for q in c)<bx[0] or min(q[0] for q in c)>bx[1] or max(q[1] for q in c)<bx[2] or min(q[1] for q in c)>bx[3])]
  if f.get('region') in UPPER_CEILINGS:
   bx=(min(q[0] for q in poly),max(q[0] for q in poly),min(q[1] for q in poly),max(q[1] for q in poly))
   use=clips+[c for c in upper_clips if not (max(q[0] for q in c)<bx[0] or min(q[0] for q in c)>bx[1] or max(q[1] for q in c)<bx[2] or min(q[1] for q in c)>bx[3])]
  for clip in use:pieces=[part for piece in pieces for part in subtract(piece,clip)]
  removed+=abs(area(poly))-sum(abs(area(a)) for a in pieces)
  for piece in pieces:
   for i in range(1,len(piece)-1):points.extend([[q[0],20,q[1]] for q in [piece[0],piece[i],piece[i+1]]])
assert removed>0
out={'source_sha256':s['source_sha256'],'ceiling_regions':ceil_ids,'floor_regions':sorted(ids),'removed_xz_area':removed,'points':points}
(ROOT/'scripts/lol2/l14_ritual_ceiling_collision.json').write_text(json.dumps(out,separators=(',',':'))+'\n')
print('clipped only upper-floor overlap:',round(removed,2),'area;',len(points)//3,'remaining original-height triangles')
