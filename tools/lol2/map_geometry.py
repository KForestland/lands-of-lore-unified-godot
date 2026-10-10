#!/usr/bin/env python3
"""Export pinned geometry for every inventoried area.

export_geometry(game_root, area_id, out) -> dict

Reuses slope_corners and the subdivision/connector interpreter. That interpreter
labels every subdivision child as a floor and clears its ceiling. Ceiling-chain
children are therefore omitted from the mesh and counted as unresolved. No
replacement role is invented. Connector diagnostics are kept as the helper
emitted them. A per-area failure does not stop the batch.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from collections import Counter
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))
INVENTORY = Path(__file__).resolve().parents[2] / 'docs' / 'game-geometry-profiles.json'
_PKG = Path(__file__).resolve().parent
if str(_PKG) not in sys.path:
    sys.path.insert(0, str(_PKG))
import interior_spans  # noqa: E402


def _helpers():
    from lol2_source_format import parse_mix, u32
    from lol2_geometry_format import s16, slope_corners, interpret
    return parse_mix, u32, s16, slope_corners, interpret


def _inventory():
    data = json.loads(INVENTORY.read_text())
    return {area['id']: area for area in data['areas']}, [area['id'] for area in data['areas']]


def _section(raw, u32, offset_field, count_field, stride):
    offset, count = u32(raw, offset_field), u32(raw, count_field)
    end = offset + count * stride
    if offset < 0 or end > len(raw):
        raise ValueError(f'Section {offset_field:#x}/{count_field:#x} exceeds geometry entry')
    return offset, count, raw[offset:end]


def _native(vertices, index, height):
    x, y = vertices[index]
    return [x / 65536, height, -y / 65536]


def _write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def export_geometry(game_root: Path, area_id: str, out: Path, *, region_snapshot: bytes | None = None) -> dict:
    """Export one pinned area. Raises if the archive pin or byte checks fail."""
    game_root = Path(game_root)
    out = Path(out)
    areas, _order = _inventory()
    if area_id not in areas:
        raise ValueError(f'Unknown area {area_id}')
    area = areas[area_id]
    src = area['source']
    parse_mix, u32, s16, slope_corners, interpret = _helpers()

    archive_path = game_root / src['file']
    archive = archive_path.read_bytes()
    archive_sha = hashlib.sha256(archive).hexdigest()
    if archive_sha != src['sha256']:
        raise ValueError(f'{area_id} archive hash does not match inventory')
    entry = next((item for item in parse_mix(archive) if item['key'] == src['geometry_key']), None)
    if entry is None:
        raise ValueError(f'{area_id} geometry key {src["geometry_key"]} missing')
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    entry_sha = hashlib.sha256(raw).hexdigest()
    if entry_sha != src['geometry_sha256']:
        raise ValueError(f'{area_id} geometry entry hash does not match inventory')
    if u32(raw, 0) != 18:
        raise ValueError(f'{area_id} geometry format marker is not 18')
    nv, nr = u32(raw, 0x50), u32(raw, 0x58)
    vo, ro = u32(raw, 4), u32(raw, 12)
    if nv != area['counts']['vertices'] or nr != area['counts']['regions']:
        raise ValueError(f'{area_id} vertex/region counts do not match inventory')
    if vo < 0 or ro < 0 or vo + nv * 8 > len(raw) or ro + nr * 44 > len(raw):
        raise ValueError(f'{area_id} vertex or region table exceeds the geometry entry')

    snapshot_source = None
    if region_snapshot is not None:
        if len(region_snapshot) != nr * 44:
            raise ValueError('Captured region table has the wrong length')
        # Only explicit surface state is imported. Pointers, lighting caches and
        # loader scratch bytes are never copied into source geometry.
        state_offsets = (20, 21, 22, 23, 28, 29, 32, 34)
        structural_offsets = tuple(range(4, 20)) + (24, 25, 26, 27, 30, 31, 33, 35, 36, 37, 38)
        patched = bytearray(raw)
        changes = []
        for index in range(nr):
            source_record = raw[ro + index * 44:ro + (index + 1) * 44]
            captured = region_snapshot[index * 44:(index + 1) * 44]
            if any(source_record[offset] != captured[offset] for offset in structural_offsets):
                raise ValueError(f'Captured region {index} changes unsupported structural fields')
            changed = [offset for offset in state_offsets if source_record[offset] != captured[offset]]
            if changed:
                changes.append(dict(region=index, byte_offsets=changed))
                for offset in changed:
                    patched[ro + index * 44 + offset] = captured[offset]
        raw = bytes(patched)
        snapshot_source = dict(region_table_sha256=hashlib.sha256(region_snapshot).hexdigest(),
            changed_regions=changes, copied_byte_offsets=list(state_offsets),
            scope='Captured floor/ceiling heights, flags and material selectors only. '
                  'Not an initial-state assertion or a replay of scripts, actors or lighting.')

    vertices = list(struct.iter_unpack('<ii', raw[vo:vo + nv * 8]))
    records = [struct.unpack_from('<22H', raw, ro + i * 44) for i in range(nr)]
    for index, record in enumerate(records):
        if any(v >= nv for v in record[6:10]):
            raise ValueError(f'{area_id} region {index} vertex reference out of range')
        if any(n != 65535 and n >= nr for n in record[2:6]):
            raise ValueError(f'{area_id} region {index} neighbor reference out of range')

    regions = []
    for i, record in enumerate(records):
        regions.append(dict(
            id=i,
            source_offset=entry['offset'] + ro + i * 44,
            raw_hex=raw[ro + i * 44:ro + (i + 1) * 44].hex(),
            vertex_indices=list(record[6:10]),
            neighbors=[None if n == 65535 else n for n in record[2:6]],
            floor_base=s16(record[10]),
            ceiling_base=s16(record[11]),
            floor_corners=slope_corners(records, i),
            ceiling_corners=slope_corners(records, i, True),
            flags=record[14],
            unknown_words=list(record[12:]),
            floor_slope=bool(record[14] & 4),
            ceiling_slope=bool(record[14] & 8),
        ))
    if b''.join(struct.pack('<ii', *vertex) for vertex in vertices) != raw[vo:vo + nv * 8]:
        raise ValueError(f'{area_id} vertex byte round trip failed')
    if b''.join(bytes.fromhex(region['raw_hex']) for region in regions) != raw[ro:ro + nr * 44]:
        raise ValueError(f'{area_id} region byte round trip failed')

    topology, corrected = interpret(vertices, records, regions)
    if b''.join(bytes.fromhex(region['raw_hex']) for region in corrected) != raw[ro:ro + nr * 44]:
        raise ValueError(f'{area_id} corrected region byte round trip failed')

    ceiling_chains = [chain for chain in topology['subdivision_chains'] if chain['surface'] == 'ceiling']
    ceiling_children = {child for chain in ceiling_chains for child in chain['children']}
    for region in corrected:
        if region['id'] in ceiling_children:
            # Helper record_role stays floor_subdivision. This flag only reports that
            # the ceiling chain was not turned into a mesh role.
            region['ceiling_chain_unresolved'] = True

    source = dict(
        area_id=area_id,
        level=area['level'],
        name=area['name'],
        file=src['file'],
        sha256=archive_sha,
        geometry_key=src['geometry_key'],
        geometry_sha256=entry_sha,
        entry=entry,
        entry_sha256=entry_sha,
    )
    if snapshot_source is not None:
        source['captured_surface_state'] = snapshot_source
    geometry = dict(
        schema='lol2-area-geometry-v1',
        source=source,
        vertices_fixed=vertices,
        regions=corrected,
        scope='Pinned source vertices and helper region records. '
               'Ceiling-chain children keep the helper floor label and are flagged unresolved; '
               'they are not given a new role. Not a completed map.',
    )
    if snapshot_source is not None:
        geometry['scope'] = ('Pinned source topology with captured surface-state fields overlaid. '
                             'Original archive hashes identify the base, not the modified region bytes. '
                             'Scripts, actor state and lighting are not restored.')

    faces = []
    inverted = []
    for region in corrected:
        if region['id'] in ceiling_children or region.get('floor_subdivisions'):
            pass
        elif region.get('floor_corners') is not None:
            faces.append(dict(
                kind='floor',
                region=region['id'],
                record_role=region.get('record_role'),
                vertex_indices=list(region['vertex_indices']),
                points=[_native(vertices, vertex, height) for vertex, height in zip(region['vertex_indices'], region['floor_corners'])],
            ))
        if region['id'] not in ceiling_children and region.get('standalone_ceiling') and region.get('ceiling_corners') is not None:
            faces.append(dict(
                kind='ceiling',
                region=region['id'],
                record_role=region.get('record_role'),
                vertex_indices=list(region['vertex_indices']),
                points=[_native(vertices, vertex, height) for vertex, height in zip(region['vertex_indices'], region['ceiling_corners'])],
            ))
        floors = region.get('floor_corners')
        ceilings = region.get('ceiling_corners')
        if region['id'] not in ceiling_children and floors and ceilings and any(floor > ceiling for floor, ceiling in zip(floors, ceilings)):
            inverted.append(region['id'])
        if not region.get('standalone_walls') or not floors or not ceilings:
            continue
        for edge, neighbor in enumerate(region['neighbors']):
            if neighbor is not None:
                continue
            nxt = (edge + 1) % 4
            v0, v1 = region['vertex_indices'][edge], region['vertex_indices'][nxt]
            faces.append(dict(
                kind='boundary',
                region=region['id'],
                edge=edge,
                vertex_indices=[v0, v1],
                points=[
                    _native(vertices, v0, floors[edge]),
                    _native(vertices, v1, floors[nxt]),
                    _native(vertices, v1, ceilings[nxt]),
                    _native(vertices, v0, ceilings[edge]),
                ],
            ))

    spans, span_audit = interior_spans.build(geometry)
    for span in spans:
        region = corrected[span['region']]
        edge = span['edge']
        ids = [region['vertex_indices'][edge], region['vertex_indices'][(edge + 1) % 4]]
        faces.append(dict(
            kind='interior',
            region=span['region'],
            edge=edge,
            neighbor=span['neighbor'],
            exposure=span['exposure']['kind'],
            vertex_indices=ids,
            points=[[coord * 64 for coord in point] for point in span['points']],
        ))

    deferred = span_audit['deferred']
    reason_counts = dict(Counter(item['reason'] for item in deferred))
    floor_ids = [face['region'] for face in faces if face['kind'] == 'floor']
    ceiling_ids = [face['region'] for face in faces if face['kind'] == 'ceiling']
    if len(floor_ids) != len(set(floor_ids)) or len(ceiling_ids) != len(set(ceiling_ids)):
        raise ValueError(f'{area_id} emitted duplicate floor or ceiling surfaces')
    owners = {region['id'] for region in corrected if region.get('floor_subdivisions')}
    if owners.intersection(floor_ids) or ceiling_children.intersection(floor_ids) or ceiling_children.intersection(ceiling_ids):
        raise ValueError(f'{area_id} emitted an owner floor or an unresolved ceiling-chain surface')

    count, start = u32(raw, 0xc4), u32(raw, 0xc8)
    names = start + count * 8
    if names < 0 or names + count * 26 != u32(raw, 0xdc) or names + count * 26 > len(raw):
        raise ValueError(f'{area_id} marker block bounds mismatch')
    markers = []
    for i in range(count):
        x, y, region, flags = struct.unpack_from('<hhHH', raw, start + i * 8)
        if region != 65535 and region >= nr:
            raise ValueError(f'{area_id} marker {i} region out of range')
        markers.append(dict(
            id=i, x=x, y=y,
            region=None if region == 65535 else region,
            flags_uninterpreted=flags,
            name=raw[names + i * 26:names + (i + 1) * 26].split(b'\0', 1)[0].decode('ascii'),
            source_offset=entry['offset'] + start + i * 8,
        ))

    arrival_offset, arrival_count, arrival_bytes = _section(raw, u32, 0x48, 0x90, 12)
    arrivals = []
    for i in range(arrival_count):
        x, y, heading, region, selector, flags, unknown = struct.unpack_from('<hhHHBBH', arrival_bytes, i * 12)
        if region != 65535 and region >= nr:
            raise ValueError(f'{area_id} arrival {i} region out of range')
        arrivals.append(dict(
            index=i, selector=selector, x=x, y=y, heading_units=heading,
            region=None if region == 65535 else region,
            source_flags=flags, unknown_tail=unknown,
            archive_offset=entry['offset'] + arrival_offset + i * 12,
        ))
    label_end = u32(raw, 0x3c)
    adjacent_labels = []
    label_note = 'unbound'
    end = arrival_offset + arrival_count * 12
    if end <= label_end <= len(raw) and label_end - end == (arrival_count - 1) * 30:
        adjacent_labels = [
            raw[end + i * 30:end + (i + 1) * 30].split(b'\0', 1)[0].decode('ascii')
            for i in range(arrival_count - 1)
        ]
    else:
        label_note = 'unbound; adjacent width does not match (count-1)*30'

    helper = topology['summary']
    unresolved = dict(
        ceiling_subdivision_chains=len(ceiling_chains),
        ceiling_subdivision_children=len(ceiling_children),
        ceiling_subdivision_note=(
            'parents_and_chains marks these chains ceiling, but interpret() stores every child as '
            'floor_subdivision and clears ceiling corners. Child surfaces are omitted. '
            'Owner slope_corners ceilings stay. No ceiling-child role was assigned.'
        ),
        interior_deferred=len(deferred),
        interior_deferred_by_reason=reason_counts,
        special_connector_directed_links=helper.get('connector_directed_links', 0),
        special_connector_unique_pairs=helper.get('connector_unique_pairs', 0),
        off_line_connector_pairs=helper.get('off_line_connector_pairs', []),
        inverted_corner_regions=inverted,
    )
    face_counts = dict(Counter(face['kind'] for face in faces))
    for kind in ('floor', 'ceiling', 'boundary', 'interior'):
        face_counts.setdefault(kind, 0)
    exposure_counts = dict(Counter(face['exposure'] for face in faces if face['kind'] == 'interior'))
    summary = dict(
        ok=True,
        area_id=area_id,
        source=dict(file=src['file'], sha256=archive_sha, geometry_key=src['geometry_key'], geometry_sha256=entry_sha),
        vertices=nv,
        regions=nr,
        markers=len(markers),
        arrivals=len(arrivals),
        byte_round_trip=True,
        byte_round_trip_scope='captured surface overlay' if snapshot_source is not None else 'pinned source',
        faces=face_counts,
        interior_exposure=exposure_counts,
        primary_regions=helper.get('primary_regions'),
        helper_floor_subdivision_records=helper.get('floor_subdivisions'),
        unresolved=unresolved,
        map_complete=False,
        scope='Static pinned geometry. Unresolved counts are omissions and deferred edges, not a finished map.',
    )
    topology_out = dict(topology)
    topology_out['unresolved_ceiling_subdivisions'] = ceiling_chains
    topology_out['interior_deferred'] = deferred
    topology_out['interior_deferred_by_reason'] = reason_counts

    out.mkdir(parents=True, exist_ok=True)
    _write(out / 'geometry.json', geometry)
    _write(out / 'faces.json', dict(
        schema='lol2-area-faces-v1',
        units='x = fixed/65536, height = source integer, z = -fixed_y/65536',
        faces=faces,
        scope='Proven floors, owner ceilings, boundary walls, and reciprocal interior spans. '
              'Ceiling-chain children and deferred connector/subdivision edges are absent here.',
    ))
    _write(out / 'topology.json', topology_out)
    _write(out / 'markers.json', dict(markers=markers, player_spawn=None,
                                      scope='Stored names and positions. No marker is the player spawn.'))
    _write(out / 'arrivals.json', dict(
        entries=arrivals, adjacent_labels=adjacent_labels, label_binding=label_note, player_spawn=None,
        scope='Source arrival records. Adjacent strings stay unbound. Not collision-safe placement.',
    ))
    _write(out / 'summary.json', summary)
    return summary


def export_all(game_root: Path, out: Path) -> list:
    """Export every inventoried area. One area's exception is recorded and skipped."""
    _areas, order = _inventory()
    out = Path(out)
    results = []
    for area_id in order:
        try:
            results.append(export_geometry(game_root, area_id, out / area_id / 'geometry'))
        except Exception as exc:
            results.append(dict(ok=False, area_id=area_id, error=f'{type(exc).__name__}: {exc}', map_complete=False))
    out.mkdir(parents=True, exist_ok=True)
    _write(out / 'batch_summary.json', dict(
        maps=len(results),
        failed=[item['area_id'] for item in results if not item.get('ok')],
        results=results,
        map_complete=False,
        scope='Per-area static geometry export. Failure of one area does not cancel the others.',
    ))
    return results


def main():
    global INVENTORY
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, default=INVENTORY, help='Pinned geometry profiles JSON')
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--area', help='One inventory area id, such as L3_DH')
    parser.add_argument('--all', action='store_true', help='Export every inventoried area under OUT/<AREA>/geometry')
    args = parser.parse_args()
    INVENTORY = args.inventory
    if args.all == bool(args.area):
        parser.error('Pass exactly one of --area or --all')
    if args.all:
        results = export_all(args.game_root, args.out)
        print(json.dumps([
            dict(area_id=item['area_id'], ok=item.get('ok'), error=item.get('error'),
                 faces=item.get('faces'), unresolved_ceiling_children=(item.get('unresolved') or {}).get('ceiling_subdivision_children'),
                 interior_deferred=(item.get('unresolved') or {}).get('interior_deferred'))
            for item in results
        ], indent=2))
    else:
        print(json.dumps(export_geometry(args.game_root, args.area, args.out), indent=2))


if __name__ == '__main__':
    main()
