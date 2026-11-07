#!/usr/bin/env python3
"""Patch generated geometry with ceiling-subdivision children.

interpret() labels every chain child floor_subdivision and clears ceiling
corners. Owner ceilings stay in faces.json, and their word 17 is the chain
pointer, so a ceiling preset read of that word walks off the preset table.

Original LOLG.DAT (file offset = VA + 0x37000):

- F3EF0: flag 0x80 returns the record; else flag 0x20 / word +0x20 walks a
  floor chain and flag 0x40 / word +0x22 walks a ceiling chain. The walk
  stops when child word +0x16 (word 11) is 0. F3D20 only tests the point.
- F5244 child draw (object byte 0x9e bit 0x40, set for flag 0x80 records):
  polygon height is F4504 when flag bit 4 is set, otherwise dword +0x12 >> 16
  (word 10). Material byte is +0x20 (word 16). Region flag 0x40 returns
  before the ceiling word-11 height path.
- F6430 skips a ceiling material when region flag 0x40 is set.

Word 11 stays the list continuation. It is not reused as a height.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
GAME_DEFAULT = Path('~/lol2_out/museum_capture_20260913/game')
OUT_DEFAULT = Path('~/lol2_out/all_maps_20260922')
EXE_HASH = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
FILE_BIAS = 0x37000
SLICES = {
    'F3EF0_chain_walk': (0xF3EF0, 0xF3FE3),
    'F3D20_point_in_polygon': (0xF3D20, 0xF3EEE),
    'F4504_floor_slope_corners': (0xF4504, 0xF458D),
    'F5244_child_height_and_selector': (0xF5309, 0xF5457),
    'F6430_skip_ceiling_when_flag40': (0xF6610, 0xF663D),
}


def _helpers():
    if str(TOOLS) not in sys.path:
        sys.path.insert(0, str(TOOLS))
    from lol2_geometry_format import s16, slope_corners
    return s16, slope_corners


def _native(vertices, index, height):
    x, y = vertices[index]
    return [x / 65536, height, -y / 65536]


def _write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')


def _records(geometry):
    rows = []
    for region in geometry['regions']:
        raw = bytes.fromhex(region['raw_hex'])
        if len(raw) != 44:
            raise ValueError(f'region {region["id"]} record is not 44 bytes')
        rows.append(struct.unpack('<22H', raw))
    return rows


def _ceiling_chains(topology, records):
    chains = [dict(chain) for chain in topology.get('subdivision_chains', []) if chain.get('surface') == 'ceiling']
    for chain in chains:
        parent = chain['parent']
        owner = records[parent]
        if not owner[14] & 0x40:
            raise ValueError(f'ceiling chain parent {parent} lacks flag 0x40')
        if owner[17] != chain['children'][0]:
            raise ValueError(f'ceiling chain parent {parent} word 17 is not the child start')
        expected = []
        index = owner[17]
        while True:
            if not 0 <= index < len(records):
                raise ValueError('ceiling chain walked out of the region table')
            child = records[index]
            if not child[14] & 0x80:
                raise ValueError(f'ceiling chain child {index} lacks flag 0x80')
            expected.append(index)
            if child[11] == 0:
                break
            index += 1
        if expected != list(chain['children']):
            raise ValueError(f'ceiling chain parent {parent} does not match word 11 links')
    return chains


def _child_heights(records, index, s16, slope_corners):
    """Heights F5244 stores for a flag-0x80 draw, in source integer units."""
    record = records[index]
    if record[14] & 4:
        side = (record[14] >> 12) & 3
        neighbor = record[2 + side]
        if neighbor == 65535:
            return None, (
                'F4504 reads dword +0x14 >> 16 when the slope neighbor is 65535. '
                'That high word is word 11, the chain continuation, so this child is left unresolved.'
            )
        if neighbor >= len(records):
            raise ValueError(f'ceiling child {index} slope neighbor out of range')
    corners = slope_corners(records, index, False)
    if not record[14] & 4:
        flat = s16(record[10])
        if corners != [flat, flat, flat, flat]:
            raise ValueError(f'ceiling child {index} flat word 10 was not reproduced')
    return corners, None


def _evidence(exe):
    if hashlib.sha256(exe).hexdigest() != EXE_HASH:
        raise ValueError('Original executable hash does not match the pinned LOLG.DAT')
    slices = {}
    for name, (start, end) in SLICES.items():
        blob = exe[start + FILE_BIAS:end + FILE_BIAS]
        slices[name] = dict(
            va_start=start, va_end=end,
            sha256=hashlib.sha256(blob).hexdigest(),
            length=len(blob),
        )
    slices['F3EF0_chain_walk']['note'] = (
        'Flag 0x80 returns the record. Nonzero arg selects flag 0x20 and word +0x20; '
        'zero selects flag 0x40 and word +0x22. Next child is +44 while word +0x16 != 0. '
        'Containment is F3D20 only.'
    )
    slices['F5244_child_height_and_selector']['note'] = (
        'Draw-object bit 0x40: material is byte +0x20. Bit 4 calls F4504; otherwise '
        'height is dword +0x12 >> 16 (word 10). Region flag 0x40 returns before dword +0x14.'
    )
    slices['F6430_skip_ceiling_when_flag40']['note'] = (
        'Region flag 0x40 skips the ceiling preset at byte +0x22. Owners keep that flag, '
        'so their ceiling plane is not drawn. Byte +0x22 on an owner is the chain index.'
    )
    return slices


def patch_geometry(geometry_root: Path, game_root: Path) -> dict:
    """Update geometry.json and faces.json. Raw region bytes and ids stay put."""
    geometry_root = Path(geometry_root)
    game_root = Path(game_root)
    s16, slope_corners = _helpers()
    geometry = json.loads((geometry_root / 'geometry.json').read_text())
    face_doc = json.loads((geometry_root / 'faces.json').read_text())
    topology = json.loads((geometry_root / 'topology.json').read_text())
    faces = face_doc['faces']
    records = _records(geometry)
    raw_before = [region['raw_hex'] for region in geometry['regions']]
    ids_before = [region['id'] for region in geometry['regions']]
    chains = _ceiling_chains(topology, records)
    exe = (game_root / 'LOLG.DAT').read_bytes()
    evidence = _evidence(exe)
    owners = {chain['parent'] for chain in chains}
    children = {child for chain in chains for child in chain['children']}
    if owners & children:
        raise ValueError('ceiling chain owner is also a child')

    gaps = []
    cases = []
    heights = {}
    for chain in chains:
        for child in chain['children']:
            corners, gap = _child_heights(records, child, s16, slope_corners)
            selector = records[child][16] & 255
            entry = dict(
                parent=chain['parent'], child=child,
                flags=records[child][14],
                word10=s16(records[child][10]),
                word11_continuation=records[child][11],
                material_selector=selector,
                slope_bit4=bool(records[child][14] & 4),
                ceiling_slope_bit8_not_used=bool(records[child][14] & 8),
            )
            if gap:
                entry['gap'] = gap
                gaps.append(entry)
            else:
                entry['corners'] = corners
                heights[child] = corners
            cases.append(entry)

    kept = []
    removed_owner_ceilings = []
    for face in faces:
        if face.get('ceiling_subdivision'):
            continue
        if face.get('kind') == 'ceiling' and face.get('region') in owners:
            removed_owner_ceilings.append(face['region'])
            continue
        kept.append(face)
    vertices = geometry['vertices_fixed']
    added = []
    regions = {region['id']: region for region in geometry['regions']}
    for chain in chains:
        owner = regions[chain['parent']]
        owner['standalone_ceiling'] = False
        owner['ceiling_plane'] = 'suppressed_flag40'
        for child in chain['children']:
            if child not in heights:
                continue
            region = regions[child]
            corners = heights[child]
            region['ceiling_subdivision_height'] = 'word10_or_F4504'
            region['ceiling_material_selector'] = records[child][16] & 255
            added.append(dict(
                kind='ceiling',
                region=child,
                record_role='ceiling_subdivision',
                ceiling_subdivision=True,
                parent=chain['parent'],
                material_selector=records[child][16] & 255,
                height_source='F5244 word10 / F4504 bit4',
                vertex_indices=list(region['vertex_indices']),
                points=[_native(vertices, vertex, height) for vertex, height in zip(region['vertex_indices'], corners)],
            ))
    if [region['raw_hex'] for region in geometry['regions']] != raw_before:
        raise ValueError('patch changed raw region bytes')
    if [region['id'] for region in geometry['regions']] != ids_before:
        raise ValueError('patch changed region ids')
    ceiling_ids = [face['region'] for face in kept + added if face['kind'] == 'ceiling']
    if len(ceiling_ids) != len(set(ceiling_ids)):
        raise ValueError('duplicate ceiling faces after the patch')
    if children & {face['region'] for face in kept if face['kind'] == 'floor'}:
        raise ValueError('ceiling child already has a floor face')

    changed = bool(chains) or len(kept) != len(faces) or added
    face_doc['faces'] = kept + added
    face_doc['scope'] = (
        'Proven floors, owner ceilings outside ceiling chains, ceiling-chain children, '
        'boundary walls, and reciprocal interior spans. '
        'Ceiling-chain owner planes are removed. Child height is word 10 / F4504. '
        'Word 11 remains the chain continuation.'
    )
    geometry['ceiling_subdivisions'] = dict(
        owners=sorted(owners),
        children=sorted(children),
        unresolved_children=[gap['child'] for gap in gaps],
        scope='Ceiling children keep their raw records and floor_subdivision role. '
              'Faces use the F5244 child height path. Owner ceiling planes are suppressed.',
    )
    report = dict(
        schema='lol2-ceiling-subdivisions-v1',
        area_id=geometry.get('source', {}).get('area_id'),
        executable_sha256=EXE_HASH,
        code_slices=evidence,
        chains=len(chains),
        children=len(children),
        owner_ceilings_removed=sorted(set(removed_owner_ceilings)),
        child_faces=len(added),
        gaps=gaps,
        cases=cases,
        word11_policy='Chain terminator only. Never copied into a corner height.',
    )
    if changed:
        _write(geometry_root / 'geometry.json', geometry)
        _write(geometry_root / 'faces.json', face_doc)
    _write(geometry_root / 'ceiling_subdivisions.json', report)
    return dict(
        area_id=report['area_id'],
        chains=len(chains),
        children=len(children),
        child_faces=len(added),
        owner_ceilings_removed=len(owners),
        owner_ceiling_faces_dropped=len(set(removed_owner_ceilings)),
        gaps=len(gaps),
    )


def patch_all(geometry_root: Path, game_root: Path) -> list:
    rows = []
    for area in sorted(path for path in Path(geometry_root).iterdir() if (path / 'geometry' / 'geometry.json').is_file()):
        rows.append(patch_geometry(area / 'geometry', game_root))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, default=GAME_DEFAULT)
    parser.add_argument('--geometry-root', type=Path, default=OUT_DEFAULT)
    args = parser.parse_args()
    rows = patch_all(args.geometry_root, args.game_root)
    for row in rows:
        print(
            f"{row['area_id']}: chains={row['chains']} children={row['children']} "
            f"faces={row['child_faces']} owners_suppressed={row['owner_ceilings_removed']} gaps={row['gaps']}"
        )


if __name__ == '__main__':
    main()
