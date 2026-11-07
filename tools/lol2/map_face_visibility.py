"""Orient structural fronts without changing the existing triangle fan.

Walls use the source edge endpoints of native F5E03 facing, not a region centroid.
Floor/ceiling fronts use their surface role. GPU backface culling is a modern
rendering policy; native integer edge rounding, portals and runtime inversion
remain separate. Assemblies, sprites and emulated boundaries stay unchanged.
"""
from collections import Counter
import numpy as np


def reverse_fan(values):
    """Keep vertex0 and the same diagonals while reversing every triangle."""
    return values[:1] + values[:0:-1]


def orient(face, regions, vertices):
    kind = face.get('kind')
    if kind not in ('floor', 'ceiling', 'source_wall'):
        return dict(face), 'unchanged'
    points = np.asarray(face['points'], dtype=float)
    normal = np.cross(points, np.roll(points, -1, axis=0)).sum(axis=0)
    if kind == 'source_wall':
        region = regions.get(face.get('region'))
        edge = face.get('edge')
        if region is None or edge not in range(4):
            return dict(face), 'unresolved_edge'
        ids = region['vertex_indices']
        a, b = vertices[ids[(edge+1)%4]], vertices[ids[edge]]
        dx, dy = b[0]-a[0], b[1]-a[1]
        length = float(np.hypot(dx, dy))
        if not length:
            return dict(face), 'degenerate'
        # Some native wall constructors emit a plane different from the source
        # edge used for admission. A GPU backface cannot reproduce that gate.
        # Allow only two fixed-point units of constructor rounding.
        xy = points[:, [0, 2]] * np.asarray([65536., -65536.])
        distance = np.abs((xy[:, 0]-a[0])*dy-(xy[:, 1]-a[1])*dx)/length
        if float(distance.max()) > 2.:
            return dict(face), 'different_admission_plane'
        # Native rejects positive (observer-a) cross (b-a). Godot fronts
        # are clockwise, so its cross normal must have the same sign.
        target_normal = np.asarray([dy, 0., dx])
        basis = 'native_source_edge_facing'
    else:
        target_normal = np.asarray([0., -1. if kind == 'floor' else 1., 0.])
        basis = 'floor_up' if kind == 'floor' else 'ceiling_down'
    dot = float(normal @ target_normal)
    if abs(dot) < 1e-8:
        return dict(face), 'degenerate'
    result = dict(face)
    if dot < 0:
        result['points'] = reverse_fan(face['points'])
        result['uv'] = reverse_fan(face['uv'])
        result['source_winding_reversed'] = not face.get('source_winding_reversed', False)
    result['front_face'] = 'clockwise'
    result['visibility_basis'] = basis
    return result, 'reversed' if dot < 0 else 'retained'


def apply(review, geometry):
    regions = {r['id']: r for r in geometry['regions']}
    counts = Counter()
    fronts = set(review.get('front_face_materials', []))
    cutouts = set(review.get('alpha_cutout_materials', []))
    faces = []
    for face in review['faces']:
        result, status = orient(face, regions, geometry['vertices_fixed'])
        counts[(face['kind'], status)] += 1
        if result.get('front_face') == 'clockwise':
            original = str(result['material'])
            result.setdefault('visibility_original_material', original)
            alias = original if original in fronts else original+'__front'
            for mapping in ('materials', 'indexed_materials', 'animations', 'shadow_masks'):
                if original in review.get(mapping, {}):
                    review[mapping][alias] = review[mapping][original]
            if original in cutouts:
                cutouts.add(alias)
            fronts.add(alias)
            result['material'] = alias
        faces.append(result)
    review['faces'] = faces
    review['front_face_materials'] = sorted(fronts)
    review['alpha_cutout_materials'] = sorted(cutouts)
    if 'summary' in review:
        review['summary']['materials'] = len(review.get('materials', {}))
    report = {'scope': __doc__, 'counts': {f'{k}/{s}': v for (k,s),v in sorted(counts.items())},
              'native_portal_admission': False, 'triangle_fans_preserved': True}
    review['structural_visibility'] = report
    return report
