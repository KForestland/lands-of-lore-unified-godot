#!/usr/bin/env python3
"""Map review inventory: source-region components and changed-geometry state counts.

Reads each area's geometry/geometry.json, geometry/arrivals.json, and review.json.
Writes <area>/review_inventory.json plus <maps-root>/review_inventory.json and
review_inventory.md. Coverage accounting only: readiness stays false, visual QA
stays pending, and prepared mechanism states are not treated as reachable.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

SCHEMA = 'lol2-map-review-inventory-v1'
PRIMARY_ROLE = 'primary_region'
WORLD_SCALE = 65536.0
WALL_KINDS = {'source_wall': 'wall', 'wall': 'wall', 'floor': 'floor', 'ceiling': 'ceiling'}


class InventoryError(Exception):
    """Malformed source topology or region identity."""


def _load(path: Path):
    with path.open(encoding='utf-8') as handle:
        return json.load(handle)


def _require_int_id(value, label: str):
    if isinstance(value, bool) or not isinstance(value, int):
        raise InventoryError(f'{label} is not an integer id: {value!r}')
    return value


def _index_regions(regions: list) -> dict:
    by_id = {}
    for record in regions:
        region_id = _require_int_id(record.get('id'), 'region id')
        if region_id in by_id:
            raise InventoryError(f'duplicate source region id {region_id}')
        role = record.get('record_role')
        if not isinstance(role, str) or not role:
            raise InventoryError(f'region {region_id} has no record_role')
        neighbors = record.get('neighbors')
        if not isinstance(neighbors, list):
            raise InventoryError(f'region {region_id} neighbors are not a list')
        by_id[region_id] = record
    if not any(record.get('record_role') == PRIMARY_ROLE for record in by_id.values()):
        raise InventoryError(
            f'no {PRIMARY_ROLE} records; inspect record_role before inventing another topology role'
        )
    return by_id


def _validate_neighbor(region_id: int, neighbor, known: dict):
    if neighbor is None:
        return None
    if isinstance(neighbor, bool) or not isinstance(neighbor, int):
        raise InventoryError(
            f'malformed neighbor reference on region {region_id}: {neighbor!r}'
        )
    if neighbor not in known:
        raise InventoryError(
            f'malformed neighbor reference on region {region_id}: {neighbor} is not a source region'
        )
    return neighbor


def _components(primary_ids: list, neighbors: dict) -> list:
    parent = {region_id: region_id for region_id in primary_ids}

    def find(region_id: int) -> int:
        while parent[region_id] != region_id:
            parent[region_id] = parent[parent[region_id]]
            region_id = parent[region_id]
        return region_id

    def union(left: int, right: int) -> None:
        root_left, root_right = find(left), find(right)
        if root_left == root_right:
            return
        if root_left < root_right:
            parent[root_right] = root_left
        else:
            parent[root_left] = root_right

    for region_id in primary_ids:
        for neighbor in neighbors[region_id]:
            if neighbor is None or neighbor not in parent or neighbor == region_id:
                continue
            union(region_id, neighbor)
    grouped = defaultdict(list)
    for region_id in primary_ids:
        grouped[find(region_id)].append(region_id)
    components = [sorted(members) for members in grouped.values()]
    components.sort(key=lambda members: (members[0], len(members), tuple(members)))
    return components


def _world_bounds(members: list, regions: dict, vertices: list) -> dict:
    xs, zs, heights, fixed_x, fixed_y = [], [], [], [], []
    for region_id in members:
        record = regions[region_id]
        for index in record.get('vertex_indices') or []:
            if isinstance(index, bool) or not isinstance(index, int) or not 0 <= index < len(vertices):
                raise InventoryError(f'region {region_id} vertex index {index!r} is outside source vertices')
            vertex = vertices[index]
            if not isinstance(vertex, (list, tuple)) or len(vertex) < 2:
                raise InventoryError(f'region {region_id} vertex {index} is not a source pair')
            sx, sy = vertex[0], vertex[1]
            fixed_x.append(sx)
            fixed_y.append(sy)
            xs.append(sx / WORLD_SCALE)
            zs.append(-sy / WORLD_SCALE)
        for key in ('floor_corners', 'ceiling_corners'):
            corners = record.get(key) or []
            if isinstance(corners, list):
                heights.extend(value for value in corners if isinstance(value, (int, float)) and not isinstance(value, bool))
    def span(values):
        if not values:
            return [None, None]
        return [min(values), max(values)]
    fixed = {'x': span(fixed_x), 'y': span(fixed_y)}
    world = None
    if xs:
        world = {
            'axes': ['x', 'height', 'z'],
            'min': [min(xs), min(heights) if heights else None, min(zs)],
            'max': [max(xs), max(heights) if heights else None, max(zs)],
            'z_from_source_y': 'negated',
            'xy_scale': WORLD_SCALE,
        }
    return {'source_fixed': fixed, 'world': world}


def _face_bucket(kind: str) -> str:
    return WALL_KINDS.get(kind, 'other')


def _issue_view(issue: dict) -> dict:
    kept = {}
    for key in ('reason', 'edge', 'surface_code', 'wall_record', 'sector', 'admission'):
        if key in issue:
            kept[key] = issue[key]
    return kept


def _provenance_rows(faces: list, sprite: bool) -> list:
    counts = defaultdict(int)
    for face in faces:
        placement = face.get('placement')
        child = face.get('child')
        mask = face.get('child_mask')
        if mask is None:
            mask = face.get('mask')
        counts[(placement, child, mask)] += 1
    rows = []
    for (placement, child, mask), count in sorted(counts.items(), key=lambda item: (str(item[0][0]), str(item[0][1]), str(item[0][2]))):
        rows.append({
            'placement': placement,
            'child': child,
            'mask': mask,
            'sprites' if sprite else 'faces': count,
        })
    return rows


def build_area(area_dir: Path) -> dict:
    area_dir = Path(area_dir)
    geometry = _load(area_dir / 'geometry' / 'geometry.json')
    arrivals_doc = _load(area_dir / 'geometry' / 'arrivals.json')
    review = _load(area_dir / 'review.json')
    if review.get('source', {}).get('sha256') and (
            review['source']['sha256'] != geometry.get('source', {}).get('sha256')):
        raise InventoryError('Geometry and review belong to different source archives')
    regions = _index_regions(geometry.get('regions') or [])
    vertices = geometry.get('vertices_fixed') or []
    primary = {}
    nonprimary = []
    directed = {}
    none_slots = defaultdict(int)
    links_to_nonprimary = []
    for region_id, record in regions.items():
        parsed = []
        for neighbor in record['neighbors']:
            resolved = _validate_neighbor(region_id, neighbor, regions)
            parsed.append(resolved)
            if resolved is None:
                none_slots[region_id] += 1
        directed[region_id] = parsed
        if record.get('record_role') == PRIMARY_ROLE:
            primary[region_id] = record
        else:
            nonprimary.append({
                'id': region_id,
                'record_role': record.get('record_role'),
                'owner': record.get('owner'),
            })
    for region_id in primary:
        for neighbor in directed[region_id]:
            if neighbor is None:
                continue
            if regions[neighbor].get('record_role') != PRIMARY_ROLE:
                links_to_nonprimary.append({'region': region_id, 'neighbor': neighbor})
    primary_ids = sorted(primary)
    groups = _components(primary_ids, directed)
    member_of = {}
    for index, members in enumerate(groups):
        for region_id in members:
            member_of[region_id] = index

    faces_by_component = [defaultdict(int) for _ in groups]
    issues_by_component = [defaultdict(list) for _ in groups]
    unassigned_faces = defaultdict(int)
    unassigned_issues = []
    for face in review.get('faces') or []:
        bucket = _face_bucket(face.get('kind'))
        region_id = face.get('region')
        if region_id in member_of and bucket in ('floor', 'ceiling', 'wall'):
            faces_by_component[member_of[region_id]][bucket] += 1
        elif face.get('kind') != 'movable':
            unassigned_faces[bucket] += 1
    for issue in review.get('geometry_issues') or []:
        region_id = issue.get('region')
        view = _issue_view(issue)
        view['region'] = region_id
        if region_id in member_of:
            issues_by_component[member_of[region_id]][region_id].append(view)
        else:
            unassigned_issues.append(view)

    arrivals = arrivals_doc.get('entries') or []
    arrivals_for = [defaultdict(list) for _ in groups]
    unassigned_arrivals = []
    for entry in arrivals:
        index = entry.get('index')
        region_id = entry.get('region')
        if region_id in member_of:
            arrivals_for[member_of[region_id]][region_id].append(index)
        else:
            unassigned_arrivals.append({
                'index': index,
                'region': region_id,
                'reason': 'region is not a primary_region component member',
            })

    components = []
    for index, members in enumerate(groups):
        issue_map = {
            str(region_id): issues_by_component[index][region_id]
            for region_id in sorted(issues_by_component[index])
        }
        arrival_map = {
            str(region_id): sorted(arrivals_for[index][region_id], key=lambda value: (value is None, str(value)))
            for region_id in sorted(arrivals_for[index])
        }
        arrival_ids = sorted(
            (value for values in arrival_map.values() for value in values),
            key=lambda value: (value is None, str(value)),
        )
        emitted = {kind: int(faces_by_component[index].get(kind, 0)) for kind in ('floor', 'ceiling', 'wall')}
        components.append({
            'component_index': index,
            'region_ids': members,
            'region_count': len(members),
            'bounds': _world_bounds(members, regions, vertices),
            'none_neighbor_slots': sum(none_slots[region_id] for region_id in members),
            'arrivals_by_region': arrival_map,
            'arrival_ids': arrival_ids,
            'emitted_faces': emitted,
            'geometry_issues_by_region': issue_map,
            'geometry_issue_count': sum(len(rows) for rows in issue_map.values()),
            'visual_qa': 'pending',
            'ready_for_content': False,
        })

    initial_faces = [
        face for face in (review.get('faces') or [])
        if face.get('kind') == 'movable'
    ]
    later_faces = list(review.get('movable_state_faces') or [])
    later_sprites = list(review.get('attached_state_props') or [])
    placements = []
    for placement in review.get('movable_placements') or []:
        placements.append({
            'index': placement.get('index', placement.get('placement')),
            'template': placement.get('template'),
            'x': placement.get('x'),
            'y': placement.get('y'),
            'height': placement.get('height'),
            'heading': placement.get('heading'),
        })
    placements.sort(key=lambda row: (row['index'] is None, str(row['index'])))
    source = geometry.get('source') or {}
    labels = list(arrivals_doc.get('adjacent_labels') or [])
    nonprimary.sort(key=lambda row: row['id'])
    links_to_nonprimary.sort(key=lambda row: (row['region'], row['neighbor']))
    unassigned_arrivals.sort(key=lambda row: (row['index'] is None, str(row['index'])))
    area_id = source.get('area_id') or review.get('id') or area_dir.name
    return {
        'schema': SCHEMA,
        'area_id': area_id,
        'name': source.get('name') or review.get('name'),
        'source': {
            'file': source.get('file'),
            'sha256': source.get('sha256'),
            'geometry_key': source.get('geometry_key'),
            'geometry_sha256': source.get('geometry_sha256'),
            'entry_sha256': source.get('entry_sha256'),
        },
        'ready_for_content': False,
        'visual_qa': 'pending',
        'adjacent_labels': {
            'names': labels,
            'binding': 'UNBOUND',
            'assigned_to_components': False,
        },
        'topology': {
            'primary_record_role': PRIMARY_ROLE,
            'edge_rule': (
                'Undirected edge when either primary_region lists the other as a neighbor. '
                'None is a boundary slot and is not a node. Child records are not component members.'
            ),
            'primary_region_count': len(primary_ids),
            'component_count': len(components),
            'components': components,
        },
        'nonprimary_regions': nonprimary,
        'primary_links_to_nonprimary': links_to_nonprimary,
        'unassigned': {
            'arrivals': unassigned_arrivals,
            'emitted_faces': {key: int(unassigned_faces.get(key, 0)) for key in ('floor', 'ceiling', 'wall', 'other')},
            'geometry_issues': unassigned_issues,
        },
        'mechanisms': {
            'placements': placements,
            'placement_count': len(placements),
            'initial_faces_by_provenance': _provenance_rows(initial_faces, sprite=False),
            'later_state_faces_by_provenance': _provenance_rows(later_faces, sprite=False),
            'later_state_sprites_by_provenance': _provenance_rows(later_sprites, sprite=True),
            'initial_face_count': len(initial_faces),
            'later_state_face_count': len(later_faces),
            'later_state_sprite_count': len(later_sprites),
            'states_all_reachable': None,
            'mechanism_function_claimed': False,
            'note': (
                'Initial placements and later-state face/sprite counts use placement, child, and mask. '
                'Counts are prepared state coverage. They do not establish that every state is reachable '
                'or that the mechanism functions.'
            ),
        },
        'scope': (
            'Review inventory of source primary_region components, emitted floor/ceiling/wall counts, '
            'geometry issues, unbound adjacent labels, and mechanism state coverage. '
            'Isolated components are not classified unused. ready_for_content remains false. '
            'Visual QA remains pending. Not a completion claim.'
        ),
    }


def _area_summary(inventory: dict) -> dict:
    mechanisms = inventory['mechanisms']
    return {
        'area_id': inventory['area_id'],
        'name': inventory['name'],
        'source': inventory['source'],
        'primary_region_count': inventory['topology']['primary_region_count'],
        'component_count': inventory['topology']['component_count'],
        'nonprimary_region_count': len(inventory['nonprimary_regions']),
        'unassigned_arrival_count': len(inventory['unassigned']['arrivals']),
        'placement_count': mechanisms['placement_count'],
        'initial_face_count': mechanisms['initial_face_count'],
        'later_state_face_count': mechanisms['later_state_face_count'],
        'later_state_sprite_count': mechanisms['later_state_sprite_count'],
        'geometry_issue_count': (sum(component['geometry_issue_count'] for component in inventory['topology']['components'])
                                 + len(inventory['unassigned']['geometry_issues'])),
        'visual_qa': 'pending',
        'ready_for_content': False,
        'adjacent_label_binding': 'UNBOUND',
        'states_all_reachable': None,
    }


def _markdown(root: dict) -> str:
    lines = [
        '# Map review inventory',
        '',
        'Source primary-region components and prepared geometry-state counts.',
        'Adjacent labels stay UNBOUND. Readiness is false. Visual QA is pending.',
        'Later-state counts are coverage, not a claim that those states are reachable or that mechanisms function.',
        'Isolated components are not classified unused.',
        '',
        '| Area | Primary regions | Components | Nonprimary | Unassigned arrivals | Placements | Initial faces | Later faces | Later sprites | Geometry issues |',
        '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    ]
    for area in root['areas']:
        lines.append(
            '| {area_id} | {primary_region_count} | {component_count} | {nonprimary_region_count} | '
            '{unassigned_arrival_count} | {placement_count} | {initial_face_count} | '
            '{later_state_face_count} | {later_state_sprite_count} | {geometry_issue_count} |'.format(**area)
        )
    lines.extend([
        '',
        f"Areas: {root['area_count']}. ready_for_content: false. visual_qa: pending.",
        'Per-area region ids, bounds, arrivals, and issue rows are in each area review_inventory.json.',
        '',
    ])
    return '\n'.join(lines)


def write_inventory(maps_root: Path) -> dict:
    maps_root = Path(maps_root)
    summaries = []
    for area_dir in sorted(path for path in maps_root.iterdir() if path.is_dir()):
        geometry_path = area_dir / 'geometry' / 'geometry.json'
        if not geometry_path.is_file():
            continue
        if not (area_dir / 'geometry' / 'arrivals.json').is_file() or not (area_dir / 'review.json').is_file():
            raise InventoryError(f'{area_dir.name} is missing arrivals.json or review.json')
        inventory = build_area(area_dir)
        destination = area_dir / 'review_inventory.json'
        destination.write_text(json.dumps(inventory, indent=2, sort_keys=False) + '\n', encoding='utf-8')
        summary = _area_summary(inventory)
        summaries.append(summary)
        print(
            f"{summary['area_id']}: components={summary['component_count']} "
            f"primary={summary['primary_region_count']} nonprimary={summary['nonprimary_region_count']} "
            f"unassigned_arrivals={summary['unassigned_arrival_count']} "
            f"placements={summary['placement_count']} later_faces={summary['later_state_face_count']} "
            f"later_sprites={summary['later_state_sprite_count']}",
            file=sys.stdout,
        )
    if not summaries:
        raise InventoryError('No exported maps found')
    root = {
        'schema': SCHEMA,
        'maps_root': str(maps_root),
        'area_count': len(summaries),
        'ready_for_content': False,
        'visual_qa': 'pending',
        'adjacent_label_binding': 'UNBOUND',
        'states_all_reachable': None,
        'areas': summaries,
        'scope': (
            'Index of per-area review inventories. Does not claim map completion, '
            'reachable mechanism states, or unused isolated sectors.'
        ),
    }
    (maps_root / 'review_inventory.json').write_text(json.dumps(root, indent=2) + '\n', encoding='utf-8')
    (maps_root / 'review_inventory.md').write_text(_markdown(root), encoding='utf-8')
    return root


def main(argv: list | None = None) -> int:
    parser = argparse.ArgumentParser(description='Build map review inventories from exported area geometry.')
    parser.add_argument('--maps-root', required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        write_inventory(args.maps_root)
    except InventoryError as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
