#!/usr/bin/env python3
"""Optional emulated quads for isolated-sector boundary gaps.

This is not a recovered native wall builder. Class 0/8 records whose neighbor
word is 65535 stay unresolved in source_walls.json: 0x114c4c and 0x114d2a
dereference that word and no caller replaces it. This tool reads those reports
and sector_admission.json, then writes a separate fallback file.

Only one-region owners listed in sector_admission are eligible, and only edges
whose geometry neighbor is missing. One closed quad uses that region's own
floor and ceiling corner heights. When an edge has both an ordinary lower
(class 0) record and an upper (class 8) record, the lower record supplies the
texture when that texture binds. Otherwise the upper record supplies it when
that texture binds. The unused record stays in provenance and is not given a
second coincident face. A positive material index must appear in materials.json.
A negative index is resolved through the area texture container with
map_surfaces.resolve_resource; if neither available class binds, the edge stays
an explicit fallback issue. Endpoint clearances of opposite sign are left
unresolved so the fallback does not emit a crossed quad. Nonfinite points or
UVs are rejected.

Full-height here means the owner floor-to-ceiling span. UV uses map_surfaces.wall_uv
on the same bottom-first frame as review binding, then is stored in the
top-first point order used by source wall faces. That full-height reading is
labelled emulated. It is not native-verified. Later admission and mechanism
state remain unresolved. The output does not make a map complete.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
from collections import defaultdict
from pathlib import Path

_PKG = Path(__file__).resolve().parent
if str(_PKG) not in sys.path:
    sys.path.insert(0, str(_PKG))

from map_source_walls import quad_area  # noqa: E402
from map_surfaces import resolve_resource, wall_uv  # noqa: E402

APPROXIMATION = (
    'Emulated full-height boundary quads for isolated one-region sectors only. '
    'Each open edge is spanned with that region\'s own floor and ceiling corner '
    'heights and a texture named by one source wall record (available lower class 0 '
    'when that texture binds, otherwise available upper class 8). '
    'Coincident class 0/8 records share one quad. This reinterprets the gap as a '
    'closed boundary; it does not replay 0x114aa4, does not recover the missing '
    'neighbor dereference, and does not assert source-exact walls or a complete map. '
    'Sector admission still does not prove unused geometry, and later mechanism '
    'state can change which regions exist.'
)

SCOPE = (
    'Optional review geometry. Original source_walls issues and sector_admission '
    'reports are inputs and are not rewritten. Ordinary connected regions are left '
    'alone. Zero or nonpositive floor-to-ceiling clearance is nonvisual and emits '
    'no quad. Opposite-sign endpoint clearance is unresolved and emits no quad. '
    'Missing texture binds, nonfinite points or UVs, and invalid shapes stay '
    'explicit fallback issues.'
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _materials_path(area_dir: Path) -> Path:
    for relative in (
        'base/materials/materials.json',
        'base/materials.json',
        'materials/materials.json',
        'materials.json',
    ):
        candidate = area_dir / relative
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f'{area_dir} has no materials.json under base/materials, base, materials, or the area root')


def _texture_blob(area_dir: Path, materials_path: Path) -> tuple[Path | None, bytes | None]:
    candidates = [
        materials_path.parent / 'texture.bin',
        area_dir / 'texture.bin',
        area_dir / 'base' / 'texture.bin',
        area_dir / 'materials' / 'texture.bin',
    ]
    seen = set()
    for candidate in candidates:
        key = str(candidate)
        if key in seen:
            continue
        seen.add(key)
        if candidate.is_file():
            return candidate, candidate.read_bytes()
    return None, None


def _native(vertices, index, height):
    x, y = vertices[index]
    return [x / 65536, height, -y / 65536]


def _issue_id(index, issue):
    return f'source_walls.issues[{index}]:region{issue["region"]}:wall{issue["wall_record"]}'


def _finite(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _finite_rows(rows) -> bool:
    return all(_finite(item) for row in rows for item in row)


def _bind_texture(record: bytes, materials: dict, texture_blob: bytes | None):
    reference = struct.unpack_from('<h', record)[0]
    indirection = None
    material_id = reference
    if reference < 0:
        if texture_blob is None:
            return None, reference, None, 'no source texture bind'
        try:
            material_id, indirection = resolve_resource(reference, texture_blob)
        except ValueError as exc:
            return None, reference, None, f'no source texture bind: {exc}'
    material = materials.get(material_id)
    if material is None:
        return None, reference, indirection, 'no source texture bind'
    width = material.get('width') or 0
    height = material.get('height') or 0
    if width <= 0 or height <= 0:
        return None, reference, indirection, 'no source texture bind'
    return material, reference, indirection, None


def _eligible_regions(admission: dict, regions: list) -> dict:
    """One-region admission owners whose four neighbors are all missing."""
    chosen = {}
    for owner in admission.get('owners') or []:
        if owner.get('region_count') != 1:
            continue
        region_id = owner.get('first')
        if not isinstance(region_id, int) or region_id < 0 or region_id >= len(regions):
            continue
        region = regions[region_id]
        neighbors = region.get('neighbors') or []
        if len(neighbors) < 4 or any(neighbor is not None for neighbor in neighbors[:4]):
            continue
        chosen[region_id] = owner
    return chosen


def build_boundary_fallbacks(area_dir: Path) -> dict:
    """Build the fallback report for one area directory. Does not write inputs."""
    area_dir = Path(area_dir)
    geometry_path = area_dir / 'geometry' / 'geometry.json'
    walls_path = area_dir / 'geometry' / 'source_walls.json'
    admission_path = area_dir / 'geometry' / 'sector_admission.json'
    materials_path = _materials_path(area_dir)
    texture_path, texture_blob = _texture_blob(area_dir, materials_path)

    geometry = json.loads(geometry_path.read_text())
    walls = json.loads(walls_path.read_text())
    admission = json.loads(admission_path.read_text())
    material_report = json.loads(materials_path.read_text())
    materials = {item['index']: item for item in material_report.get('materials') or []}
    regions = geometry['regions']
    vertices = geometry['vertices_fixed']
    eligible = _eligible_regions(admission, regions)

    grouped = defaultdict(list)
    for index, issue in enumerate(walls.get('issues') or []):
        if issue.get('reason') != 'absent neighbor':
            continue
        code = issue.get('surface_code')
        if code is None or code & 0x10 or (code & 12) not in (0, 8):
            continue
        region_id = issue.get('region')
        edge = issue.get('edge')
        if region_id not in eligible or edge not in (0, 1, 2, 3):
            continue
        grouped[(region_id, edge)].append((index, issue))

    faces = []
    nonvisual = []
    unresolved = []
    for (region_id, edge), rows in sorted(grouped.items()):
        region = regions[region_id]
        owner = eligible[region_id]
        covered = [_issue_id(index, issue) for index, issue in rows]
        lowers = [(index, issue) for index, issue in rows if (issue['surface_code'] & 12) == 0]
        uppers = [(index, issue) for index, issue in rows if (issue['surface_code'] & 12) == 8]
        def _prepared(row):
            index, issue = row
            try:
                record = bytes.fromhex(issue['raw_hex'])
            except ValueError:
                return dict(index=index, issue=issue, record=None, invalid=True)
            if len(record) != 8:
                return dict(index=index, issue=issue, record=None, invalid=True)
            material, reference, indirection, bind_problem = _bind_texture(record, materials, texture_blob)
            return dict(
                index=index,
                issue=issue,
                record=record,
                invalid=False,
                material=material,
                reference=reference,
                indirection=indirection,
                bind_problem=bind_problem,
            )

        def _binds(prep):
            return prep is not None and not prep['invalid'] and not prep['bind_problem']

        lower_prep = _prepared(lowers[0]) if len(lowers) == 1 else None
        upper_prep = _prepared(uppers[0]) if len(uppers) == 1 else None
        if len(lowers) > 1 or (not _binds(lower_prep) and len(uppers) > 1):
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='ambiguous source wall records',
                covered_source_issue_ids=covered,
            ))
            continue
        chosen_prep = lower_prep if _binds(lower_prep) else upper_prep if _binds(upper_prep) else None
        if chosen_prep is None:
            failed = lower_prep or upper_prep
            if failed is None or failed['invalid']:
                unresolved.append(dict(
                    region=region_id,
                    sector=owner.get('sector'),
                    edge=edge,
                    reason='invalid shape',
                    covered_source_issue_ids=covered,
                ))
            else:
                unresolved.append(dict(
                    region=region_id,
                    sector=owner.get('sector'),
                    edge=edge,
                    reason=failed['bind_problem'],
                    texture_reference=failed['reference'],
                    covered_source_issue_ids=covered,
                    chosen_wall_record=failed['issue']['wall_record'],
                ))
            continue
        chosen = chosen_prep['issue']
        record = chosen_prep['record']
        material = chosen_prep['material']
        reference = chosen_prep['reference']
        indirection = chosen_prep['indirection']
        floors = region.get('floor_corners')
        ceilings = region.get('ceiling_corners')
        indices = region.get('vertex_indices') or []
        nxt = (edge + 1) % 4
        if not floors or not ceilings or len(floors) < 4 or len(ceilings) < 4 or len(indices) < 4:
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='invalid shape',
                covered_source_issue_ids=covered,
            ))
            continue
        if not all(_finite(floors[slot]) and _finite(ceilings[slot]) for slot in (edge, nxt)):
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='nonfinite point or uv',
                covered_source_issue_ids=covered,
            ))
            continue
        clearance = (
            ceilings[edge] - floors[edge],
            ceilings[nxt] - floors[nxt],
        )
        if clearance[0] * clearance[1] < 0:
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='unresolved mixed clearance',
                clearance=list(clearance),
                covered_source_issue_ids=covered,
                chosen_wall_record=chosen['wall_record'],
            ))
            continue
        if max(clearance) <= 0:
            nonvisual.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='nonpositive clearance',
                clearance=list(clearance),
                covered_source_issue_ids=covered,
                chosen_wall_record=chosen['wall_record'],
            ))
            continue
        v0, v1 = indices[edge], indices[nxt]
        if not isinstance(v0, int) or not isinstance(v1, int) or isinstance(v0, bool) or isinstance(v1, bool) or min(v0, v1) < 0 or max(v0, v1) >= len(vertices):
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='invalid shape',
                covered_source_issue_ids=covered,
            ))
            continue
        if not _finite_rows((vertices[v0], vertices[v1])):
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='nonfinite point or uv',
                covered_source_issue_ids=covered,
            ))
            continue
        points = [
            _native(vertices, v0, ceilings[edge]),
            _native(vertices, v1, ceilings[nxt]),
            _native(vertices, v1, floors[nxt]),
            _native(vertices, v0, floors[edge]),
        ]
        area = quad_area(points)
        if not _finite_rows(points) or not math.isfinite(area) or area <= 1e-9:
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='nonfinite point or uv' if not _finite_rows(points) or not math.isfinite(area) else 'invalid shape',
                covered_source_issue_ids=covered,
            ))
            continue
        try:
            # Review binding feeds wall_uv a bottom-first reversal of native points.
            uv = list(reversed(wall_uv(list(reversed(points)), record, material)))
        except ValueError as exc:
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason=f'invalid shape: {exc}',
                covered_source_issue_ids=covered,
            ))
            continue
        if not _finite_rows(uv):
            unresolved.append(dict(
                region=region_id,
                sector=owner.get('sector'),
                edge=edge,
                reason='nonfinite point or uv',
                covered_source_issue_ids=covered,
            ))
            continue
        suppressed = [
            dict(
                source_issue_id=_issue_id(index, issue),
                wall_record=issue['wall_record'],
                surface_code=issue['surface_code'],
                wall_class=issue['surface_code'] & 12,
            )
            for index, issue in rows
            if issue is not chosen
        ]
        faces.append(dict(
            kind='emulated_boundary',
            provenance='optional_isolated_sector_boundary_fallback',
            native_verified=False,
            fullheight='emulated',
            region=region_id,
            sector=owner.get('sector'),
            edge=edge,
            surface_code=chosen['surface_code'],
            wall_class=chosen['surface_code'] & 12,
            wall_record=chosen['wall_record'],
            raw_hex=chosen['raw_hex'],
            vertical_offset=record[3],
            material_record_id=material['index'],
            material=str(material['index']),
            texture_reference=reference,
            texture_indirection=indirection,
            covered_source_issue_ids=covered,
            suppressed_coincident_records=suppressed,
            points=points,
            uv=uv,
        ))

    covered_ids = []
    for bucket in (faces, nonvisual, unresolved):
        for item in bucket:
            covered_ids.extend(item['covered_source_issue_ids'])
    payload = dict(
        schema='lol2-boundary-fallback-v1',
        label='emulated geometry fallback',
        native_verified=False,
        maps_complete=False,
        area_id=admission.get('area_id') or geometry.get('source', {}).get('area_id'),
        approximation=APPROXIMATION,
        scope=SCOPE,
        later_state_uncertainty=admission.get('scope'),
        source_hashes=dict(
            geometry_sha256=_sha256(geometry_path),
            source_walls_sha256=_sha256(walls_path),
            sector_admission_sha256=_sha256(admission_path),
            materials_sha256=_sha256(materials_path),
            texture_sha256=_sha256(texture_path) if texture_path else None,
        ),
        source_paths=dict(
            geometry=str(geometry_path),
            source_walls=str(walls_path),
            sector_admission=str(admission_path),
            materials=str(materials_path),
            texture=str(texture_path) if texture_path else None,
        ),
        faces=faces,
        nonvisual=nonvisual,
        unresolved=unresolved,
        summary=dict(
            eligible_one_region_sectors=len(eligible),
            emulated_faces=len(faces),
            nonvisual=len(nonvisual),
            unresolved=len(unresolved),
            covered_source_issues=len(covered_ids),
            covered_source_issue_ids=covered_ids,
            chosen_material_record_ids=sorted({face['material_record_id'] for face in faces}),
            chosen_wall_record_ids=sorted({face['wall_record'] for face in faces}),
            native_verified=False,
            maps_complete=False,
        ),
    )
    return payload


def export_area(area_dir: Path, out: Path) -> dict:
    payload = build_boundary_fallbacks(area_dir)
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'boundary_fallbacks.json').write_text(json.dumps(payload, indent=2) + '\n')
    return payload


def _areas(maps_root: Path, area: str | None) -> list[Path]:
    maps_root = Path(maps_root)
    if area:
        return [maps_root / area]
    found = []
    for child in sorted(maps_root.iterdir()):
        if child.is_dir() and (child / 'geometry' / 'sector_admission.json').is_file():
            found.append(child)
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--area', default=None, help='One area id. Omit to export every area under --maps-root.')
    parser.add_argument('--maps-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args(argv)
    rows = []
    for area_dir in _areas(args.maps_root, args.area):
        payload = export_area(area_dir, args.out / area_dir.name)
        summary = payload['summary']
        rows.append(dict(
            area_id=payload['area_id'],
            emulated_faces=summary['emulated_faces'],
            nonvisual=summary['nonvisual'],
            unresolved=summary['unresolved'],
            covered_source_issues=summary['covered_source_issues'],
            native_verified=False,
            maps_complete=False,
        ))
    print(json.dumps(rows, indent=2))
    return rows


if __name__ == '__main__':
    main()
