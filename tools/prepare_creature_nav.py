#!/usr/bin/env python3
"""Export compact region-portal navigation graphs for live creatures (modern adapter).

Source region quads, floors and neighbour edges from the pinned all-map geometry.
Edges keep portals at least 24 units wide between regions with >=47 units of
standing clearance and <=32 units of floor step, the same filters as the earned
route builders. No native pathfinder parity is claimed.
"""
import argparse,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MAPS=Path('~/lol2_out/all_maps_20260922')
AREAS = ('L1_DC', 'L3_DH', 'L4_HJ', 'L5_HC', 'L8_SJ', 'L10_DC', 'L13_RC', 'L16_CA', 'L19_BC', 'L9_DR', 'L12_CM', 'L14_HT', 'L17_HC', 'L20_BB')

def build(area, maps):
    g=json.loads((maps/area/'geometry/geometry.json').read_text())
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
    return data

def write(data, output_root):
    area=data['area']
    path=output_root/f'assets/lol2/generated/creature_nav/{area}.json'
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,separators=(',',':')))
    print(area,len(data['regions']),'regions',sum(len(x[3]) for x in data['regions']),'edges',path.stat().st_size,'bytes')

def export(area, maps=MAPS, output_root=ROOT):
    write(build(area, maps), output_root)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--maps',type=Path,default=MAPS,help='geometry root containing AREA/geometry/geometry.json')
    parser.add_argument('--output-root',type=Path,default=ROOT,help='root receiving assets/lol2/generated/creature_nav')
    parser.add_argument('--area',action='append',choices=AREAS,help='only these areas (default: all); the others keep their graphs')
    args=parser.parse_args()
    # Build every graph before replacing output, so a bad later input preserves prior graphs.
    graphs=[build(area,args.maps) for area in (args.area or AREAS)]
    for data in graphs: write(data,args.output_root)

if __name__=='__main__':main()
