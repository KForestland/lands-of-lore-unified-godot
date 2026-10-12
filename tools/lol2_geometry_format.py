"""Shared source geometry slope, subdivision and connector interpretation.

Moved unchanged from project RE helpers. Existing unresolved ceiling subdivision
and connector interpretation limits are retained; this is not a geometry fix.
"""
import collections, math

def s16(n): return n-65536 if n & 32768 else n

def slope_corners(records, i, ceiling=False):
    """Port of original routines 0xF4504 / 0xF4590, gated by flags 4 / 8.
    Heights returned in signed original integer units, before 16.16 expansion.
    """
    r=records[i]; flag=8 if ceiling else 4
    base=s16(r[11 if ceiling else 10])
    corners=[base]*4
    if r[14]&flag:
        side=(r[14]>>(14 if ceiling else 12))&3
        other=r[2+side]
        if other==65535:
            edge=s16(r[10 if ceiling else 11])
        else:
            if other>=len(records):raise ValueError('Slope neighbor out of bounds')
            edge=s16(records[other][11 if ceiling else 10])
        corners[side]=corners[(side+1)%4]=edge
    return corners

def audit(verts,records,regions):
    edges=collections.defaultdict(list)
    for i,r in enumerate(records):
        for k in range(4):edges[tuple(sorted((r[6+k],r[6+(k+1)%4])))].append((i,k))
    nonrec=[];mismatch=[];directed=0;match=0;reciprocal=0
    for i,r in enumerate(records):
        for k,n in enumerate(r[2:6]):
            if n==65535:continue
            directed+=1
            if i in records[n][2:6]:reciprocal+=1
            else:nonrec.append([i,k,n])
            edge=tuple(sorted((r[6+k],r[6+(k+1)%4])))
            if any(j==n for j,_ in edges[edge]):match+=1
            else:mismatch.append([i,k,n])
    graph=[set() for _ in records]
    for i,r in enumerate(records):
        for n in r[2:6]:
            if n!=65535:graph[i].add(n);graph[n].add(i)
    remaining=set(range(len(records)));components=[]
    while remaining:
        queue=[min(remaining)];component=set()
        while queue:
            v=queue.pop()
            if v in component:continue
            component.add(v);queue.extend(graph[v]-component)
        remaining-=component;components.append(sorted(component))
    inverted=[];nonplanar=[]
    for r in regions:
        if any(f>c for f,c in zip(r['floor_corners'],r['ceiling_corners'])):inverted.append(r['id'])
        for name in ['floor_corners','ceiling_corners']:
            ps=[(verts[v][0]/65536,h,verts[v][1]/65536) for v,h in zip(r['vertex_indices'],r[name])]
            a=[ps[1][j]-ps[0][j] for j in range(3)];b=[ps[2][j]-ps[0][j] for j in range(3)];c=[ps[3][j]-ps[0][j] for j in range(3)]
            cross=[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
            normal=math.sqrt(sum(x*x for x in cross))
            distance=abs(sum(x*y for x,y in zip(c,cross)))/normal if normal else 0
            if distance>0.01:nonplanar.append(dict(region=r['id'],surface=name,fourth_corner_plane_distance=distance))
    return dict(vertices=len(verts),regions=len(records),directed_neighbors=directed,
        reciprocal_neighbors=reciprocal,shared_edge_neighbors=match,
        nonreciprocal=nonrec,neighbor_edge_mismatches=mismatch,
        edge_multiplicity=dict(collections.Counter(len(v) for v in edges.values())),
        components=sorted(components,key=lambda c:-len(c)),floor_slope_regions=sum(r['floor_slope'] for r in regions),
        ceiling_slope_regions=sum(r['ceiling_slope'] for r in regions),
        inverted_corner_regions=inverted,nonplanar_surfaces=nonplanar),edges

def parents_and_chains(records):
    parents={}
    for i,r in enumerate(records):
        if r[14]&0x80:
            p=i-1
            while p>=0 and records[p][14]&0x80:p-=1
            if p<0:raise ValueError('Subdivision has no preceding owner')
            parents[i]=p
    chains=[]
    for i,r in enumerate(records):
        if i in parents:continue  # F3EF0 returns early for child records.
        for field,flag,slot in [('floor',0x20,16),('ceiling',0x40,17)]:
            if not r[14]&flag:continue
            start=r[slot];ids=[];j=start
            while True:
                if not 0<=j<len(records):raise ValueError('Subdivision chain out of bounds')
                if parents.get(j)!=i:raise ValueError('Chain member has different owner')
                ids.append(j)
                if records[j][11]==0:break
                j+=1
            chains.append(dict(parent=i,surface=field,start=start,children=ids,
                continuation_words=[records[j][11] for j in ids],
                proof='F3EF0 selects +32/+34, increments by 44, stops at +22 == 0; F3Cxx scans backward over flag 128.'))
    if set(parents)!=set(j for c in chains for j in c['children']):raise ValueError('Unaccounted subdivision records')
    return parents,chains

def edge_points(verts,records,region,side):
    ids=records[region][6:10]
    return [verts[ids[k]] for k in (side,(side+1)%4)]

def connector_side(records, connector, caller):
    """Native B18EC..B1921 / 114B08..114B45 chooses 0 when +4 names caller, else 2."""
    if not records[connector][14]&0x10:raise ValueError('Not a flagged connector')
    side=0 if records[connector][2]==caller else 2
    if records[connector][2+side]!=caller:raise ValueError('Caller not attached to selected connector side')
    return side

def compare_edges(a,b):
    a=[(x/65536,y/65536) for x,y in a];b=[(x/65536,y/65536) for x,y in b]
    u=[a[1][j]-a[0][j] for j in range(2)];length=math.hypot(*u)
    if not length:raise ValueError('Zero-length connector approach')
    distance=[abs(u[0]*(p[1]-a[0][1])-u[1]*(p[0]-a[0][0]))/length for p in b]
    t=[sum((p[j]-a[0][j])*u[j] for j in range(2))/(length*length) for p in b]
    return dict(max_line_distance_original_units=max(distance),connector_projection_on_approach=t,
                overlap_fraction=max(0,min(1,max(t))-max(0,min(t))),
                collinear_within_two_fixed_lsb=max(distance)<=2/65536)

def interpret(verts,records,regions):
    parents,chains=parents_and_chains(records);old,edges=audit(verts,records,regions)
    links=[]
    for i,k,n in old['neighbor_edge_mismatches']:
        row=dict(source=i,side=k,target=n)
        if parents.get(i)==n:
            row['kind']='subdivision_to_owner'
        else:
            if records[n][14]&0x10:connector=n;caller=i
            elif records[i][14]&0x10:connector=i;caller=n
            else:raise ValueError('Unclassified exceptional link')
            side=connector_side(records,connector,caller)
            caller_side=records[caller][2:6].index(connector)
            a=edge_points(verts,records,caller,caller_side);b=edge_points(verts,records,connector,side)
            row.update(kind='flag16_connector',connector=connector,caller=caller,
                connector_side=side,caller_side=caller_side,approach_endpoints_fixed=a,
                selected_endpoints_fixed=b,comparison=compare_edges(a,b))
        links.append(row)
    nonrec=[dict(source=i,side=k,target=n,kind='subdivision_to_owner' if parents.get(i)==n else 'unresolved') for i,k,n in old['nonreciprocal']]
    if any(x['kind']=='unresolved' for x in nonrec):raise ValueError('Unclassified nonreciprocal link')
    # Add role-aware fields. Keep the old raw record bytes for byte-for-byte round trips.
    corrected=[]
    for r in regions:
        r=dict(r);i=r['id'];r['storage_word_22']=records[i][11]
        if i in parents:
            r.update(record_role='floor_subdivision',owner=parents[i],ceiling_base=None,ceiling_corners=None,
                list_continuation=records[i][11],floor_link_flag=False,ceiling_link_flag=False,
                standalone_ceiling=False,standalone_walls=False)
        else:r.update(record_role='primary_region',owner=None,standalone_ceiling=True,standalone_walls=True)
        r['floor_subdivisions']=next((c['children'] for c in chains if c['parent']==i and c['surface']=='floor'),[])
        corrected.append(r)
    summary=dict(primary_regions=len(records)-len(parents),floor_subdivisions=len(parents),
        exceptional_links=len(links),exception_classes=dict(collections.Counter(x['kind'] for x in links)),
        nonreciprocal_links=len(nonrec),nonreciprocal_owner_links=len(nonrec),
        connector_directed_links=sum(x['kind']=='flag16_connector' for x in links),
        connector_unique_pairs=len({tuple(sorted((x['source'],x['target']))) for x in links if x['kind']=='flag16_connector'}),
        off_line_connector_pairs=sorted({tuple(sorted((x['source'],x['target']))) for x in links if x['kind']=='flag16_connector' and not x['comparison']['collinear_within_two_fixed_lsb']}))
    return dict(summary=summary,subdivision_chains=chains,exceptional_links=links,nonreciprocal_links=nonrec),corrected
