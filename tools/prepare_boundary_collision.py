#!/usr/bin/env python3
"""Height-aware source-wall census, reusable for any area; no native decoding.

Inputs are existing decoded geometry, portable map faces, and the previous
boundary adapter's selected edges. Outputs add collision keys, never geometry.
The probe keeps the previous 10-unit/three-sample/48-step policy, but compares
actual interpolated floor AND ceiling spans at the wall's height. A stacked
room is not a passage. Linked edges admit only collision below a rise exceeding STEP. Whole faces
below the opening use block_face_keys; a face crossing the opening gets only
its lower clipped collision polygon in collision_faces. Rendered faces never change.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

STEP = 48.0
MIN_OPENING = 8.0  # Existing minimum fitted body, not a new clearance rule.
PROBE = 10.0
SAMPLES = (0.2, 0.5, 0.8)
CELL = 256.0


def lerp(a, b, t):
    return a + (b - a) * t


def height_at(poly, heights, point):
    """Source quad triangulation 0,1,2 / 0,2,3, including sloped surfaces."""
    x, z = point
    for indices in ((0, 1, 2), (0, 2, 3)):
        a, b, c = (poly[i] for i in indices)
        det = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(det) < 1e-9:
            continue
        u = ((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(z-c[1]))/det
        v = ((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(z-c[1]))/det
        w = 1-u-v
        if min(u, v, w) >= -1e-6:
            return sum(weight*heights[i] for weight, i in zip((u,v,w), indices))
    return None


def face_key(face):
    ends = sorted(set((round(p[0]), round(p[2])) for p in face['points']))
    if len(ends) != 2:
        return None
    # RegionEdgeRule.face_key uses first-encounter endpoint order, not sorting.
    ends = list(dict.fromkeys((round(p[0]), round(p[2])) for p in face['points']))
    low = round(min(p[1] for p in face['points']))
    high = round(max(p[1] for p in face['points']))
    return f"{face['kind']}|{ends[0][0]},{ends[0][1]}|{ends[1][0]},{ends[1][1]}|{low}|{high}"


def clip_polygon(poly, signed_distance):
    """Clip (edge parameter,height) polygon, preserving source winding."""
    out=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da,db=signed_distance(a),signed_distance(b)
        if da>=-1e-7:
            out.append(a)
        if (da<0<db) or (db<0<da):
            t=da/(da-db)
            out.append((lerp(a[0],b[0],t),lerp(a[1],b[1],t)))
    clean=[]
    for point in out:
        if not clean or math.dist(point,clean[-1])>1e-7:
            clean.append(point)
    if len(clean)>1 and math.dist(clean[0],clean[-1])<1e-7:
        clean.pop()
    return clean


def polygon_area(poly):
    return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))*0.5


def lower_collision_parts(face, region, neighbour, polys, surface, floor_minimum):
    """Only the existing wall below an elevated opening; never close its slot.

    Split at source/target quad diagonals and floor crossover/STEP thresholds,
    then clip the source wall polygon against the exact linear portal floor.
    Output is collision-only polygons, not changes to any rendered source face.
    """
    ends=list(dict.fromkeys((p[0],p[2]) for p in face['points']))
    if len(ends)!=2:
        return []
    a,b=ends;dx,dz=b[0]-a[0],b[1]-a[1];length2=dx*dx+dz*dz
    if length2<1e-9:
        return []
    at=lambda t:(a[0]+dx*t,a[1]+dz*t)
    breaks={0.0,1.0}
    # Split at diagonals AND the neighbour's partial-side boundaries. A native
    # link may meet only the middle of this edge (Temple36->35 is such a slot).
    for index in (region,neighbour):
        poly=polys[index]
        segments=[(poly[0],poly[2]),*zip(poly,poly[1:]+poly[:1])]
        for c,d in segments:
            ex,ez=d[0]-c[0],d[1]-c[1]
            det=dx*ez-dz*ex
            if abs(det)>1e-9:
                t=((c[0]-a[0])*ez-(c[1]-a[1])*ex)/det
                u=((c[0]-a[0])*dz-(c[1]-a[1])*dx)/det
                if 1e-7<t<1-1e-7 and -1e-7<=u<=1+1e-7:breaks.add(t)
    def floor(index,point):
        value=surface(index,'floor_corners',point)
        # Outside the neighbour's narrower polygon there is no portal. Use its
        # minimum decoded floor as a conservative lower cut there, never above
        # any real opening. Boundary splits keep this fallback out of the slot.
        return floor_minimum(index) if value is None and index==neighbour else value
    first=sorted(breaks)
    for left,right in zip(first,first[1:]):
        values=[]
        for t in (left,right):
            x=floor(region,at(t));y=floor(neighbour,at(t))
            if x is None or y is None:break
            values.append(x-y)
        if len(values)!=2:continue
        d0,d1=values
        if abs(d1-d0)<1e-9:continue
        for threshold in (-STEP,0.0,STEP):
            fraction=(threshold-d0)/(d1-d0)
            if 1e-7<fraction<1-1e-7:breaks.add(lerp(left,right,fraction))
    original=[(((p[0]-a[0])*dx+(p[2]-a[1])*dz)/length2,p[1]) for p in face['points']]
    parts=[];ordered=sorted(breaks)
    for left,right in zip(ordered,ordered[1:]):
        mid=(left+right)/2
        own=floor(region,at(mid));other=floor(neighbour,at(mid))
        if own is None or other is None or abs(own-other)<=STEP+1e-7:continue
        higher=region if own>other else neighbour
        lo=floor(higher,at(left));hi=floor(higher,at(right))
        if lo is None or hi is None:continue
        roof=lambda t:lerp(lo,hi,(t-left)/(right-left))
        poly=clip_polygon(original,lambda p:p[0]-left)
        poly=clip_polygon(poly,lambda p:right-p[0])
        poly=clip_polygon(poly,lambda p:roof(p[0])-p[1])
        if len(poly)<3 or polygon_area(poly)<1e-7:continue
        parts.append({'points':[[at(t)[0],height,at(t)[1]] for t,height in poly],
                      'interval':[left,right],'portal_floor':[lo,hi]})
    return parts


def census(geometry, pack, previous=None, moving_regions=()):
    previous = previous or {}
    regions = geometry['regions']
    moving_regions=set(moving_regions)
    floor_faces={f.get('region') for f in pack['faces'] if f.get('kind')=='floor'}
    ceiling_only={f.get('region') for f in pack['faces'] if f.get('kind')=='ceiling' and f.get('record_role')=='ceiling_subdivision'}-floor_faces
    vertices = geometry['vertices_fixed']
    polys = [[(vertices[i][0]/65536, -vertices[i][1]/65536)
              for i in row['vertex_indices']] for row in regions]
    grid = {}
    for index, poly in enumerate(polys):
        if len(poly) != 4:
            continue
        for gx in range(math.floor(min(p[0] for p in poly)/CELL), math.floor(max(p[0] for p in poly)/CELL)+1):
            for gz in range(math.floor(min(p[1] for p in poly)/CELL), math.floor(max(p[1] for p in poly)/CELL)+1):
                grid.setdefault((gx,gz), []).append(index)
    def surface(region, field, point, seen=()):
        if region in seen:
            return None
        row = regions[region]
        values = row.get(field)
        if values is not None:
            return height_at(polys[region], values, point)
        owner = row.get('owner')
        if isinstance(owner,int) and 0 <= owner < len(regions):
            return surface(owner,field,point,(*seen,region))
        return None
    def floor_minimum(index):
        values=regions[index].get('floor_corners')
        return min(values) if values else None
    old = {tuple(pair) for pair in previous.get('edges', [])}
    rows = []
    blocks = set()
    partials = []
    for index, face in enumerate(pack['faces']):
        if face.get('kind') not in ('source_wall','wall'):
            continue
        region, edge = face.get('region'), face.get('edge')
        if not isinstance(region, int) or not isinstance(edge, int) or not 0 <= region < len(regions):
            continue
        key = face_key(face)
        if key is None or len(polys[region]) != 4:
            continue
        native = regions[region]
        neighbour = native['neighbors'][edge]
        if neighbour is None and (region,edge) in old:
            continue  # Existing solid walls are preserved verbatim.
        withheld=None
        if region in moving_regions or neighbour in moving_regions:
            withheld='script_or_live_floor'
        elif region in ceiling_only or neighbour in ceiling_only:
            withheld='ceiling_only_surface_not_floor'
        elif neighbour is not None:
            # A sloping top does not prove a solid volume underneath it. The
            # Temple bench/overhang traces demonstrate why this inference is
            # unsafe. Withhold these candidates pending specific volume proof.
            own=regions[region].get('floor_corners') or []
            other=regions[neighbour].get('floor_corners') or []
            if (own and max(own)-min(own)>1e-6) or (other and max(other)-min(other)>1e-6):
                withheld='unqualified_sloped_floor_volume'
        if withheld:
            rows.append({'face':index,'region':region,'edge':edge,'native_neighbour':neighbour,
                         'selected':False,'reason':withheld,'samples':[]})
            continue
        a, b = polys[region][edge], polys[region][(edge+1)%4]
        dx, dz = b[0]-a[0], b[1]-a[1]
        length = math.hypot(dx, dz)
        if length < 1e-6:
            continue
        nx, nz = -dz/length, dx/length
        centre = tuple(sum(p[k] for p in polys[region])/4 for k in (0,1))
        if nx*(centre[0]-(a[0]+b[0])/2)+nz*(centre[1]-(a[1]+b[1])/2)>0:
            nx, nz = -nx, -nz
        low, high = min(p[1] for p in face['points']), max(p[1] for p in face['points'])
        samples = []
        for t in SAMPLES:
            on_edge = (lerp(a[0],b[0],t),lerp(a[1],b[1],t))
            origin_floor = surface(region,'floor_corners',on_edge)
            origin_ceiling = surface(region,'ceiling_corners',on_edge)
            if origin_floor is None or origin_ceiling is None:
                samples.append({'t':t,'unclassified':True,'candidates':[{'usable':True}]})
                continue
            if neighbour is not None:
                target = regions[neighbour]
                floor = surface(neighbour,'floor_corners',on_edge)
                ceiling = surface(neighbour,'ceiling_corners',on_edge)
                if floor is None or ceiling is None:
                    continue
                bottom, top = max(origin_floor,floor), min(origin_ceiling,ceiling)
                samples.append({'t':t,'native_opening':[bottom,top]})
                continue
            point = (on_edge[0]+nx*PROBE,on_edge[1]+nz*PROBE)
            candidates = []
            for other in grid.get((math.floor(point[0]/CELL),math.floor(point[1]/CELL)), []):
                if other == region:
                    continue
                target = regions[other]
                floor = surface(other,'floor_corners',point)
                ceiling = surface(other,'ceiling_corners',point)
                if floor is None or ceiling is None:
                    continue
                overlap = min(high,origin_ceiling,ceiling)-max(low,origin_floor,floor)
                usable = abs(floor-origin_floor) <= STEP and overlap >= MIN_OPENING-1e-6
                candidates.append({'region':other,'floor':floor,'ceiling':ceiling,'usable':usable})
            samples.append({'t':t,'origin_floor':origin_floor,'origin_ceiling':origin_ceiling,'point':point,'candidates':candidates})
        if neighbour is None:
            keep_open = any(c['usable'] for sample in samples for c in sample['candidates'])
            # Report all previously excluded null faces, including those kept open.
            selected = not keep_open
            reason = 'null_neighbour_height_block' if selected else 'null_neighbour_passage_preserved'
        else:
            parts = lower_collision_parts(face,region,neighbour,polys,surface,floor_minimum)
            if not parts:
                continue
            # A complete lower face can use the existing whole-face adapter.
            ends=list(dict.fromkeys((p[0],p[2]) for p in face['points']))
            dx,dz=ends[1][0]-ends[0][0],ends[1][1]-ends[0][1]
            length2=dx*dx+dz*dz
            project=lambda point:(((point[0]-ends[0][0])*dx+(point[2]-ends[0][1])*dz)/length2,point[1])
            original_area=polygon_area([project(p) for p in face['points']])
            selected=abs(sum(polygon_area([project(p) for p in part['points']]) for part in parts)-original_area)<1e-6
            reason='linked_raised_floor_band' if selected else 'linked_lower_partial_band'
            if not selected:
                for part in parts:
                    partials.append({'face':index,'region':region,'edge':edge,'native_neighbour':neighbour,**part})
        if selected:
            blocks.add(key)
        rows.append({'face':index,'region':region,'edge':edge,'native_neighbour':neighbour,
                     'height':[low,high],'key':key,'selected':selected,'reason':reason,'samples':samples})
    null_block = {(r['region'],r['edge']) for r in rows if r['reason']=='null_neighbour_height_block'}
    null_open = {(r['region'],r['edge']) for r in rows if r['reason']=='null_neighbour_passage_preserved'}
    linked = {(r['region'],r['edge']) for r in rows if r['reason']=='linked_raised_floor_band'}
    return {'version':2,'area':pack['area'],'rule':'native corner heights; outward10, samples0.2/0.5/0.8, step48, overlap8; linked lower collision clipped to native portal floor; source art unchanged',
            'block_face_keys':sorted(blocks),'collision_faces':partials,'counts':{'new_null_edges':len(null_block),'preserved_null_edges':len(null_open),'linked_band_edges':len(linked),'added_face_keys':len(blocks),'partial_band_faces':len({p['face'] for p in partials}),'collision_polygons':len(partials),'withheld_dynamic_faces':sum(r['reason']=='script_or_live_floor' for r in rows),'withheld_ceiling_only_faces':sum(r['reason']=='ceiling_only_surface_not_floor' for r in rows),'withheld_sloped_faces':sum(r['reason']=='unqualified_sloped_floor_volume' for r in rows)},'rows':rows}


def validate_inputs(geometry, pack, previous):
    source = geometry.get('source', {})
    if source.get('area_id') != pack.get('area') or (previous and previous.get('area') != pack.get('area')):
        raise ValueError('geometry, map and previous selection must name the same area')
    fingerprint = source.get('geometry_sha256')
    if not fingerprint or fingerprint != pack.get('source', {}).get('geometry_sha256') or (previous and fingerprint != previous.get('geometry_sha256')):
        raise ValueError('native geometry fingerprints do not match')
    # Captured export variants can share an archive fingerprint but have changed
    # live corner heights. Require the export matching this actual portable map.
    regions = geometry['regions']
    vertices = geometry['vertices_fixed']
    for face in pack['faces']:
        if face.get('kind') != 'floor' or face.get('record_role') != 'primary_region':
            continue
        region = int(face['region'])
        row = regions[region]
        poly = [(vertices[i][0]/65536, -vertices[i][1]/65536) for i in row['vertex_indices']]
        from collections import Counter
        actual=Counter((round(x,6),round(y,6),round(z,6)) for x,y,z in face['points'])
        expected=Counter((round(p[0],6),round(y,6),round(p[1],6)) for p,y in zip(poly,row['floor_corners']))
        if actual!=expected:
            raise ValueError(f'corner heights differ at region{region}; use the geometry export matching this map')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('geometry','map','scripts','out','report'):
        parser.add_argument('--'+name,required=True,type=Path)
    parser.add_argument('--previous',type=Path,help='Optional legacy selected-edge packet; omit for a fresh area')
    parser.add_argument('--live-floor-source',type=Path,action='append',default=[],help='Additional audited live floor-writer JSON with regions or floors array')
    args=parser.parse_args()
    paths={'geometry':args.geometry,'map':args.map,'scripts':args.scripts}
    for index,path in enumerate(args.live_floor_source):paths[f'live_floor_source_{index}']=path
    if args.previous:paths['previous']=args.previous
    data={name:json.loads(path.read_text()) for name,path in paths.items()}
    validate_inputs(data['geometry'],data['map'],data.get('previous',{}))
    if data['scripts'].get('area')!=data['map'].get('area'):
        parser.error('script export area does not match map')
    moving={int(command['target']) for group in data['scripts']['groups'] for command in group['commands'] if int(command['opcode'])==196}
    for name,value in data.items():
        if not name.startswith('live_floor_source_'):continue
        values=value.get('regions',value.get('floors'))
        if not isinstance(values,list) or any(not isinstance(i,int) for i in values):
            parser.error(f'{name} must declare an audited regions or floors integer array')
        moving.update(values)
    # Subdivision floors can follow their owner's live surface; retain no static
    # inference for those descendants either.
    changed=True
    while changed:
        changed=False
        for index,row in enumerate(data['geometry']['regions']):
            if row.get('owner') in moving and index not in moving:
                moving.add(index);changed=True
    result=census(data['geometry'],data['map'],data.get('previous',{}),moving)
    result['excluded_live_floor_regions']=sorted(moving)
    result['producer_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    result['inputs']={name:{'sha256':hashlib.sha256(path.read_bytes()).hexdigest()} for name,path in paths.items()}
    result['native_source']=data['geometry']['source']
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(result,indent=2)+'\n')
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps({k:v for k,v in result.items() if k not in ('rows','native_source')},indent=2)+'\n')
    print(json.dumps(result['counts'],sort_keys=True))


if __name__=='__main__':
    main()
