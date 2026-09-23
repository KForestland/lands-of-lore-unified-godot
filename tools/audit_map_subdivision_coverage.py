#!/usr/bin/env python3
"""Projected subdivision coverage diagnostics; source meshes are never modified."""
import argparse
from collections import Counter, defaultdict
import math
import json
from pathlib import Path

from audit_map_floor_coverage import digest


def cross(a, b, c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def area(poly):
    return abs(sum(poly[i][0]*poly[(i+1)%len(poly)][1]-
                   poly[(i+1)%len(poly)][0]*poly[i][1] for i in range(len(poly))))/2


def triangles(poly):
    result = []
    for i in range(1, len(poly)-1):
        tri = [poly[0], poly[i], poly[i+1]]
        if abs(cross(*tri)) < 1e-10:
            continue
        if cross(*tri) < 0:
            tri.reverse()
        result.append(tri)
    return result


def intersection(subject, clip):
    """Sutherland-Hodgman clipping against a counterclockwise triangle."""
    result = list(subject)
    for i in range(3):
        a, b = clip[i], clip[(i+1)%3]
        source, result = result, []
        if not source:
            break
        previous = source[-1]
        pd = cross(a, b, previous)
        for current in source:
            cd = cross(a, b, current)
            if (cd >= 0) != (pd >= 0):
                t = pd/(pd-cd)
                result.append((previous[0]+t*(current[0]-previous[0]),
                               previous[1]+t*(current[1]-previous[1])))
            if cd >= 0:
                result.append(current)
            previous, pd = current, cd
    return result


def measure(parent, children):
    # Translate locally to avoid cancellation at large source coordinates.
    origin = parent[0]
    local = lambda p: [(v[0]-origin[0], v[1]-origin[1]) for v in p]
    pt = triangles(local(parent))
    ct = [t for polygon in children for t in triangles(local(polygon))]
    parent_area = sum(area(t) for t in pt)
    child_area = sum(area(t) for t in ct)
    inside = sum(area(intersection(c, p)) for c in ct for p in pt)
    overlaps = sum(area(intersection(a, b)) for i, a in enumerate(ct) for b in ct[i+1:])
    parent_overlap = sum(area(intersection(a, b)) for i, a in enumerate(pt) for b in pt[i+1:])
    tolerance = max(0.01, parent_area*1e-7)
    outside = max(0.0, child_area-inside)
    # With no overlap, area deficit is uncovered parent area. Otherwise it is
    # only a deficit bound; pairwise overlap sums are not a polygon union.
    deficit = max(0.0, parent_area-inside)
    issues = []
    if not pt: issues.append('zero-area parent')
    if parent_overlap > tolerance: issues.append('overlapping parent fan; union unresolved')
    if outside > tolerance: issues.append('child surface outside parent projection')
    if overlaps > tolerance: issues.append('overlapping child triangle projections')
    if deficit > tolerance: issues.append('uncovered projected area lower bound')
    return {'parent_area': parent_area, 'child_triangle_area': child_area,
            'outside_area': outside, 'pairwise_overlap_area': overlaps,
            'uncovered_area_lower_bound': deficit, 'parent_fan_overlap': parent_overlap,
            'tolerance_area': tolerance, 'issues': issues}


def boundary_metrics(parent, children):
    """Exact shared-edge cancellation; T junctions remain explicitly unresolved."""
    edges = Counter()
    for polygon in children:
        for i, a in enumerate(polygon):
            b = polygon[(i+1)%len(polygon)]
            if a != b:
                edges[tuple(sorted((tuple(a), tuple(b))))] += 1
    boundary = [edge for edge, count in edges.items() if count == 1]
    graph = defaultdict(set)
    for a, b in boundary:
        graph[a].add(b)
        graph[b].add(a)
    unusual = sum(len(adjacent) != 2 for adjacent in graph.values())
    remaining, components = set(graph), 0
    while remaining:
        components += 1
        pending = [remaining.pop()]
        while pending:
            for neighbor in graph[pending.pop()]:
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    pending.append(neighbor)

    def distance(p, a, b):
        dx, dy = b[0]-a[0], b[1]-a[1]
        length2 = dx*dx+dy*dy
        t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/length2)) if length2 else 0
        return math.hypot(p[0]-a[0]-t*dx, p[1]-a[1]-t*dy)

    deviation = max((min(distance(p, a, parent[(i+1)%len(parent)])
                         for i, a in enumerate(parent)) for p in graph), default=0)
    return {'boundary_edges': len(boundary), 'boundary_components': components,
            'non_degree_two_vertices': unusual, 'edges_used_more_than_twice': sum(n > 2 for n in edges.values()),
            'max_boundary_vertex_distance_to_parent_edge': deviation,
            'single_closed_outline': components == 1 and unusual == 0 and all(n <= 2 for n in edges.values())}


def audit(root):
    gp, rp = root/'geometry/geometry.json', root/'review.json'
    geometry, review = json.loads(gp.read_text()), json.loads(rp.read_text())
    regions = {r['id']: r for r in geometry['regions']}
    faces = {(f['kind'], f.get('region')): f for f in review['faces'] if f['kind'] in ('floor', 'ceiling')}
    groups = []
    for region in geometry['regions']:
        if region.get('floor_subdivisions'):
            groups.append(('floor', region['id'], region['floor_subdivisions']))
    ceilings = defaultdict(list)
    ceiling_path = root/'geometry/ceiling_subdivisions.json'
    for case in json.loads(ceiling_path.read_text())['cases']:
        ceilings[case['parent']].append(case['child'])
    groups.extend(('ceiling', owner, children) for owner, children in ceilings.items())
    rows = []
    for kind, owner, ids in groups:
        parent = [(geometry['vertices_fixed'][v][0]/65536,
                   -geometry['vertices_fixed'][v][1]/65536) for v in regions[owner]['vertex_indices']]
        polygons = [[(p[0], p[2]) for p in faces[(kind, child)]['points']]
                    for child in ids if (kind, child) in faces]
        absent = [child for child in ids if (kind, child) not in faces]
        nonvisual = [child for child in absent if bytes.fromhex(regions[child]['raw_hex'])[32] == 255]
        holes = [[(geometry['vertices_fixed'][v][0]/65536, -geometry['vertices_fixed'][v][1]/65536)
                  for v in regions[child]['vertex_indices']] for child in nonvisual]
        row = {'kind': kind, 'owner': owner, 'children': ids,
               'explicit_nonvisual_children': nonvisual,
               'missing_rendered_children': [child for child in absent if child not in nonvisual],
               'rendered_coverage': measure(parent, polygons)}
        # Source-declared holes count toward the intended partition footprint,
        # but remain visibly absent in rendered_coverage.
        row.update(measure(parent, polygons+holes))
        row['boundary'] = boundary_metrics(parent, polygons+holes)
        rows.append(row)
    return {'area': root.name, 'geometry_sha256': digest(gp), 'review_sha256': digest(rp),
            'ceiling_chain_sha256': digest(ceiling_path), 'groups': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--map-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    index = args.map_root/'index.json'
    rows = [audit(args.map_root/a['id']) for a in json.loads(index.read_text())['areas']]
    report = {'scope': 'XZ projected rendered triangle coverage. No height continuity or native admission claim. '
              'Pairwise overlap is diagnostic, not a union calculation. Intentional holes need interpretation.',
              'index_sha256': digest(index), 'areas': rows,
              'groups': sum(len(r['groups']) for r in rows),
              'flagged_groups': sum(bool(g['issues'] or g['missing_rendered_children']) for r in rows for g in r['groups'])}
    args.out.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: report[k] for k in ('groups', 'flagged_groups')}))
    return int(report['flagged_groups'] > 0)


if __name__ == '__main__':
    raise SystemExit(main())
