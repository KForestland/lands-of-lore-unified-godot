#!/usr/bin/env python3
"""Export compact region-portal navigation graphs for live creatures (modern adapter).

Source region quads, floors and neighbour edges from the pinned all-map geometry.
Edges keep portals at least 24 units wide between regions with >=47 units of
standing clearance and <=32 units of floor step, the same filters as the earned
route builders. No native pathfinder parity is claimed.
"""
import json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MAPS=Path('/home/bob/lol2_out/all_maps_20260922')
def export(area):
    g=json.loads((MAPS/area/'geometry/geometry.json').read_text())
    V=g['vertices_fixed'];R=g['regions'];out=[]
    def ok(r): return r.get('ceiling_corners') is not None and r.get('floor_corners') is not None and len(r.get('vertex_indices') or [])==4
    for i,r in enumerate(R):
        if not ok(r):
            out.append([[],0,0,[]]);continue
        quad=[[V[v][0]/65536,-V[v][1]/65536] for v in r['vertex_indices']]
        clear=min(c-f for c,f in zip(r['ceiling_corners'],r['floor_corners']))
        edges=[]
        if clear>=47:
            for e,n in enumerate(r['neighbors']):
                if n is None: continue
                o=R[n]
                if not ok(o): continue
                if min(c-f for c,f in zip(o['ceiling_corners'],o['floor_corners']))<47: continue
                ids=[r['vertex_indices'][e],r['vertex_indices'][(e+1)%4]]
                if not all(v in o['vertex_indices'] for v in ids): continue
                diffs=[abs(r['floor_corners'][r['vertex_indices'].index(v)]-o['floor_corners'][o['vertex_indices'].index(v)]) for v in ids]
                if max(diffs)>32: continue
                a,b=V[ids[0]],V[ids[1]]
                if math.dist(a,b)/65536<24: continue
                edges.append([n,round((a[0]+b[0])/131072,2),round(-(a[1]+b[1])/131072,2)])
        out.append([[[round(p[0],2),round(p[1],2)] for p in quad],min(r['floor_corners']),max(r['floor_corners']),edges])
    data=dict(version=1,area=area,source_sha256=g['source']['sha256'],regions=out)
    path=ROOT/f'assets/lol2/generated/creature_nav/{area}.json';path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,separators=(',',':')))
    print(area,len(out),'regions',sum(len(x[3]) for x in out),'edges',path.stat().st_size,'bytes')
if __name__=='__main__':
    for area in ['L1_DC','L3_DH','L4_HJ','L5_HC']: export(area)
