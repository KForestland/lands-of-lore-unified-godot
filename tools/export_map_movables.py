#!/usr/bin/env python3
"""Export one area's initial movable or static-assembly geometry from explicit inputs.

Portable closure of unpublished tools/lol2/map_movables.py. Install this file
as tools/export_map_movables.py. --tools-root is that tools directory: it
contains this program, lol2/map_materials.py, lol2/map_surfaces.py,
lol2_rotation_table.py, lol2_source_format.py, lol2_texture_container.py, and
lol2_material_format.py. Published map_materials.py reads
docs/game-geometry-profiles.json from the parent of --tools-root. --re-root is
the RE tree that contains tools/draracle; only that draracle directory is
inserted. There is no default checkout and LOL2_RE_ROOT is not read.

Face order, template records, and the bounded constructor witness stay the
unpublished exporter's. map_materials has no RE_TOOLS attribute. The rotation
table is lol2_rotation_table.rotation_table for the supplied game. One area
and one placement kind per run. The output directory must not exist.

materials_root in the written report is the resolved parent of the selected
materials.json. Accepted layouts are material-root/AREA/materials/materials.json,
material-root/AREA/materials.json, and material-root/materials.json. The bundle
area, archive file, archive sha256, and geometry key must match the area being
exported. Every face and state-face image must exist at materials_root joined
with its material path before the report is written.

Shared whole-game LoL2 movable pipeline: export source *initial-state* visual
geometry for movable objects (doors/bridges/mechanisms) for any of the 15
pinned level MIXes in docs/game-source-inventory.json.

Entry identification reuses tools/lol2/map_materials.identify_entries() (not
edited here) so the geometry/metadata split stays a single source of truth.
The metadata entry holds a 60-byte template table, each template followed by
0+ 60-byte "children" (the door object's own single child, at template index
6/13 in L1_DC, is the only member of this table previously decoded anywhere
in this codebase -- see ~/lol2_re_publish_20260911/tools/draracle's
extract_cave_object_templates.py, verify_assembly_child_modes.py,
verify_door_surface_slots.py, verify_door_face_geometry.py and
verify_door_material_bindings.py). This module generalizes exactly what those
tools already proved about that shared 60-byte child record to every
placement in every area, adding nothing unproven:

  * child byte59 ("type_byte") 0 is this exporter's face-box class (the door's
    own child is type0). Type1 children are attached props exported separately
    by tools/lol2/map_primitive_geometry.py (dispatch 0x5AFA8). This module
    does not invent type1 vertices. Any other type_byte is reported under
    `issues` as an unsupported child class, never guessed.
  * a type0 child's 6 axis-aligned box faces come from 4 signed XY bytes and 2 unsigned Z bytes at
    offset52 (xmin,xmax,ymin,ymax,zmin,zmax) -- verify_door_face_geometry.py
    replayed the native per-face vertex-construction dispatch (shared code,
    not door-specific: it was replayed against two additional synthetic
    bound tuples besides the door's own) and recorded each face's exact
    4-vertex order; those 6 fixed vertex orders are reproduced verbatim in
    `_FACE_VERTEX_ORDER` below. A face whose 8-byte surface slot has a signed
    resource id of 0 has no geometry (matches the door script's own
    `if not face_surface_id: continue`). A negative id is resolved through
    the TEXTURE container blob with map_surfaces.resolve_resource (global
    0x22D54, header fields 0x20/0x5c); a rejected indirection is reported,
    never guessed.
  * verify_door_material_bindings.py proved descriptor = resource_id + frame
    for a positive resource id; for the initial (frame0) state this is
    exactly resource_id, which is also exactly the tools/lol2/map_materials.py
    `materials[].index` value (confirmed here: door surfaces 470/85 resolve
    to the same two entries the other worker's L1_DC materials.json already
    contains). A resource id absent from that bundle (rejected/unsupported
    texture format, or the bundle not yet exported for this area) is reported
    under `issues` for the initial draw, or under `state_issues` for a later
    visual state, never guessed at.
  * world position/heading reuse the native fixed-point rotation replayed and
    proven generic (not door-specific) in verify_chain_rotation.py's
    `model(point, origin, angle, table)`, called once per vertex with the
    placement's own native (x,y) origin and heading. The door hinge witness
    (~/lol2_out/chain_rotation_20260913/rotation.json) shows this
    formula's "closed"/progress0 pose is *exact* (delta_from_anchor_fixed is
    [0, 0] for both doors75/79 at progress0) -- i.e. the door's own initial
    pose already collapses to `model(local_xy, placement_origin, heading,
    table)` with no extra hinge-pivot term, which is exactly the formula
    used here for every placement. `test_map_movables.py` replays this
    against that same door75/79 witness data.
  * the native base-XYZ constructor (0xAE99A..0xAE9CE, previously replayed
    only for L3_DH in tools/export_museum_movables.py) is replayed again
    here for every placement in every area as a bounded sanity witness; it is
    the same LOLG.DAT code regardless of area.

Vertical height is untouched by rotation (native world height = local z +
placement height, both already in native units); points are exported as
(X, height, -Y) native units, the existing project-wide export convention
(see tools/export_museum_props.py, docs/recovered-doors.md).

Initial activation mode is the constant written by the movable constructor
at 0x5B66A (`mov byte [obj+0x3d], 0`) and passed to the proven child-count
body 0x5A8AC (`sar dword [obj+0x3a], 24` at 0x5B67A). The same byte is the
mode the renderer tests at 0x5E156 (`mask & (1<<mode)`). Mode 0 is therefore
the only initial selection; later writes at 0x5D558 are runtime changes and
are not applied. A child whose mask bit0 is clear is metadata under
`inactive_children`, not an `issues` row, and is not part of `faces`.
Mask 0 stays metadata only (no draw). A type0 child with a nonzero mask
whose bit0 is clear keeps its faces in `state_faces` (actual mask, placement,
child, template, source bounds, and the same placement rotation) so a later
visual state can be shown without activating it now.

Type1 is a separate dispatch at 0x5AFA8 (`cmp al,1` / `jbe 0x5B4E4`), owned
by map_primitive_geometry.py. This exporter does not draw those children and
does not substitute box vertices for them. A mode-0 type1 child is noted
under `issues` only so the omission is visible beside the type0 faces.

A negative type0 surface id uses the TEXTURE blob via
`map_surfaces.resolve_resource`: 0x5B41B negates the id, indexes the table
at global 0x22D54 by 8, and forms `uint16 + byte7`.
`verify_hive_surface_indirection.py` assigns that global from the geometry
entry's header fields 0x20/0x5c. The indirect record's byte7 replaces the
slot frame (0x5B435 then 0x5B440). Positive ids stay resource_id (frame0),
matching verify_door_material_bindings.py. The same decode is used for
`state_faces`. No trigger, motion or collision is inferred from mask bits
or from the trailing placement bytes.

The 8 bytes following each 41-byte placement's template index stay verbatim
in `motion_bytes_hex`. They are not a mode.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

# Published modules load only after explicit roots are checked.
mm = ms = None
EXE_HASH = None
ConstructorReplay = None
model = signed = capstone = rotation_table = None
require = sha256_hex = None

ROTATION_TABLE_SHA256 = 'd7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'


def bind(tools_root: Path, re_root: Path) -> None:
    """Load published Godot readers and the RE 2791eb1 draracle helpers."""
    global mm, ms, EXE_HASH, ConstructorReplay, model, signed, capstone
    global rotation_table, require, sha256_hex
    tools_root, re_root = tools_root.resolve(), re_root.resolve()
    draracle = re_root / 'tools' / 'draracle'
    lol2 = tools_root / 'lol2'
    needed = [
        lol2 / 'map_materials.py', lol2 / 'map_surfaces.py',
        tools_root / 'lol2_rotation_table.py',
        tools_root / 'lol2_source_format.py',
        tools_root / 'lol2_texture_container.py',
        tools_root / 'lol2_material_format.py',
        draracle / 'lol2_verify_draracle_slopes.py',
        draracle / 'lol2_verify_spatial_constructor.py',
        draracle / 'verify_chain_rotation.py',
        draracle / 'verify_creature_states.py',
    ]
    missing = [str(path) for path in needed if not path.is_file()]
    if missing:
        raise ValueError('Missing published helper: ' + missing[0])
    for path in (lol2, tools_root, draracle):
        entry = str(path)
        if entry not in sys.path:
            sys.path.insert(0, entry)
    import map_materials as materials
    import map_surfaces as surfaces
    from lol2_verify_draracle_slopes import EXE_HASH as exe_hash
    from lol2_verify_spatial_constructor import ConstructorReplay as replay_cls
    from verify_chain_rotation import model as rotate
    from verify_creature_states import signed as sign
    import capstone as cs
    from lol2_rotation_table import rotation_table as table_fn
    mm, ms = materials, surfaces
    EXE_HASH, ConstructorReplay = exe_hash, replay_cls
    model, signed, capstone = rotate, sign, cs
    rotation_table = table_fn
    require, sha256_hex = mm.require, mm.sha256_hex

CONSTRUCTOR_CODE_RANGE = (0xae99a, 0xae9ce)

# Constructor 0x5B66A / 0x5B67A. Not read from the 41-byte placement.
INITIAL_MODE = 0

# Exact per-face 4-vertex order, replayed against the shared native dispatch
# in verify_door_face_geometry.py (order (x, z, y); z is height, untouched by
# rotation). Face index -> surface slot -> vertex order.
_FACE_VERTEX_ORDER = [
    lambda b: [(b[0], b[5], b[3]), (b[0], b[5], b[2]), (b[1], b[5], b[2]), (b[1], b[5], b[3])],
    lambda b: [(b[0], b[4], b[2]), (b[0], b[4], b[3]), (b[1], b[4], b[3]), (b[1], b[4], b[2])],
    lambda b: [(b[0], b[5], b[2]), (b[1], b[5], b[2]), (b[1], b[4], b[2]), (b[0], b[4], b[2])],
    lambda b: [(b[1], b[5], b[3]), (b[0], b[5], b[3]), (b[0], b[4], b[3]), (b[1], b[4], b[3])],
    lambda b: [(b[1], b[5], b[2]), (b[1], b[5], b[3]), (b[1], b[4], b[3]), (b[1], b[4], b[2])],
    lambda b: [(b[0], b[5], b[3]), (b[0], b[5], b[2]), (b[0], b[4], b[2]), (b[0], b[4], b[3])],
]
_QUAD_UV = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
_QUAD_UV_FACE3 = [(1.0, 0.0), (0.0, 0.0), (0.0, 1.0), (1.0, 1.0)]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from('<I', data, offset)[0]


def load_movable_templates(meta: bytes) -> dict:
    """Parse the 60-byte template/child table (see module docstring)."""
    require(len(meta) >= 0x48, 'metadata entry too small for the movable template header')
    to, nt = u32(meta, 12), u32(meta, 0x44)
    require(to + nt * 60 + 4 <= len(meta), 'template table exceeds metadata entry')
    co = to + nt * 60 + 4
    nchild = u32(meta, co - 4)
    require(co + nchild * 60 <= len(meta), 'child table exceeds metadata entry')
    children = [meta[co + j * 60:co + (j + 1) * 60] for j in range(nchild)]
    templates, cursor = [], 0
    for i in range(nt):
        t = meta[to + i * 60:to + (i + 1) * 60]
        count = t[50]
        require(cursor + count <= nchild, 'template exceeds child table')
        parts = []
        for j in range(cursor, cursor + count):
            c = children[j]
            bounds = struct.unpack_from('<4b2B', c, 52)
            surfaces = [dict(resource_id=struct.unpack_from('<h', c, f * 8)[0],
                              raw_hex=c[f * 8:f * 8 + 8].hex()) for f in range(6)]
            parts.append(dict(index=j, type_byte=c[59], mask=u32(c, 48),
                               bounds=list(bounds), surfaces=surfaces, raw_hex=c.hex()))
        templates.append(dict(index=i, child_count=count, dimensions=list(t[47:50]),
                               children=parts, raw_hex=t.hex()))
        cursor += count
    require(cursor == nchild, 'unaccounted children')
    return dict(templates=templates, child_count=nchild)


def _constructor_replay(exe: bytes) -> ConstructorReplay:
    a, z = CONSTRUCTOR_CODE_RANGE
    code = exe[a + 0x37000:z + 0x37000]
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    rows = list(md.disasm(code, a))
    require(rows[-1].address + rows[-1].size == z, 'constructor instruction boundary mismatch')
    return ConstructorReplay({i.address: i for i in rows}, b'')


def _box_faces(bounds: list[int]) -> list[list[tuple[int, int, int]]]:
    return [order(bounds) for order in _FACE_VERTEX_ORDER]


def placement_table(geometry: bytes, kind: str = 'movable') -> tuple[int, list[bytes]]:
    """Native static33 (header18/64) and movable41 (header24/70) tables."""
    require(kind in ('movable', 'static_assembly'), 'unknown assembly placement kind')
    offset_field, count_field, stride = (0x24, 0x70, 41) if kind == 'movable' else (0x18, 0x64, 33)
    require(len(geometry) >= count_field + 4, 'geometry header too short')
    start, count = u32(geometry, offset_field), u32(geometry, count_field)
    require(start + count * stride <= len(geometry), 'assembly placement table exceeds geometry')
    return start, [geometry[start+i*stride:start+(i+1)*stride] for i in range(count)]


def placement_identity(index: int, kind: str) -> int | str:
    return index if kind == 'movable' else f'static_{index}'


def select_materials(material_root: Path, area_id: str, source: dict) -> tuple[dict, Path]:
    """Return index->image and the parent of the selected materials.json.

    Consumers join that parent with face['material']. Every accepted layout
    uses the same parent rule.
    """
    candidates = (
        material_root / area_id / 'materials' / 'materials.json',
        material_root / area_id / 'materials.json',
        material_root / 'materials.json',
    )
    candidate = next((path for path in candidates if path.is_file()), None)
    require(candidate is not None, f'materials bundle not found under {material_root} for {area_id}')
    bundle = json.loads(candidate.read_text())
    require(bundle.get('area_id') == area_id,
            f'{candidate}: material area {bundle.get("area_id")!r} does not match {area_id}')
    pinned = bundle.get('source')
    require(isinstance(pinned, dict), f'{candidate}: material bundle has no source binding')
    require(pinned.get('file') == source['file'],
            f'{candidate}: material archive {pinned.get("file")!r} does not match {source["file"]}')
    require(pinned.get('sha256') == source['sha256'],
            f'{candidate}: material archive hash does not match {source["file"]}')
    require(pinned.get('geometry_key') == source['geometry_key'],
            f'{candidate}: material geometry key does not match {area_id}')
    material_map = {}
    for row in bundle.get('materials') or []:
        require(isinstance(row, dict) and 'index' in row and isinstance(row.get('image'), str),
                f'{candidate}: material row missing index or image')
        material_map[row['index']] = row['image']
    return material_map, candidate.parent.resolve()


def require_material_images(image_root: Path, faces: list[dict]) -> None:
    root = image_root.resolve()
    for face in faces:
        relative = Path(face['material'])
        require(not relative.is_absolute() and '..' not in relative.parts,
                f'material image escapes the selected materials directory: {face["material"]}')
        path = root / relative
        require(path.resolve().is_relative_to(root) and path.is_file(),
                f'missing material image: {path}')


def export_movables(game_root: Path, area_id: str, out: Path, material_root: Path, *, placement_kind: str = 'movable') -> dict:
    """Export static initial-state movable geometry for one pinned level MIX into `out`.

    Returns the same report dict written to `out/movables.json`.
    """
    inventory = mm.load_inventory()
    area = mm.area_by_id(inventory, area_id)
    source = area['source']

    mix = (game_root / source['file']).read_bytes()
    require(sha256_hex(mix) == source['sha256'], f'{area_id}: unsupported or changed archive')
    exe = (game_root / 'LOLG.DAT').read_bytes()
    require(sha256_hex(exe) == EXE_HASH, f'{area_id}: unsupported or changed executable')
    material_map, image_root = select_materials(material_root, area_id, source)
    materials_pending = False

    entries = mm.parse_mix(mix)
    identity = mm.identify_entries(mix, entries, source['geometry_key'])
    geo_entry, meta_entry = identity['geometry_entry'], identity['metadata_entry']
    geo = mix[geo_entry['offset']:geo_entry['offset'] + geo_entry['size']]
    meta = mix[meta_entry['offset']:meta_entry['offset'] + meta_entry['size']]
    texture_blob, _ = mm.decode_lzo_container(mix, identity['texture_entry'])
    parsed = load_movable_templates(meta)
    templates = parsed['templates']

    po, placements = placement_table(geo, placement_kind)
    npl = len(placements)
    stride = 41 if placement_kind == 'movable' else 33

    # Bounded native base-XYZ constructor witness (previously replayed only for
    # L3_DH in tools/export_museum_movables.py); same LOLG.DAT code every area.
    replay = _constructor_replay(exe)
    obj, record = 0x500000, 0x600000
    constructor_mismatches = []
    for i, d in enumerate(placements):
        x, y, heading, height = struct.unpack_from('<hhHh', d)
        replay.mem[record:record + 41] = d
        replay.regs.update(ebx=obj, edx=record)
        replay.span(*CONSTRUCTOR_CODE_RANGE)
        actual = [signed(replay.readmem(obj + k * 4, 4)) for k in range(3)]
        if actual != [x << 16, y << 16, height << 16]:
            constructor_mismatches.append(i)

    table_bytes = rotation_table(game_root)
    require(sha256_hex(table_bytes) == ROTATION_TABLE_SHA256, 'rotation table does not match the published pin')
    rtable = struct.unpack('<4096i', table_bytes)

    faces, issues, inactive_children = [], [], []
    state_faces, state_issues = [], []
    placement_records = []
    child_type_counts: dict[int, int] = {}
    for pi, d in enumerate(placements):
        x, y, heading, height = struct.unpack_from('<hhHh', d)
        template_index = d[32]
        placement_id = placement_identity(pi, placement_kind)
        base = dict(placement=placement_id, placement_kind=placement_kind, source_index=pi, template=template_index,
                    placement_offset=geo_entry['offset'] + po + pi * stride,
                    placement_hex=d.hex(), motion_bytes_hex=d[33:].hex())
        # Every source placement, including ones with no drawn child, for later
        # animation bindings. motion_bytes_hex stays verbatim; it is not a mode.
        placement_records.append(dict(
            index=pi, x=x, y=y, heading=heading, height=height,
            fixed_origin=[x << 16, y << 16], **base))
        if template_index >= len(templates):
            issues.append(dict(**base, reason='template index outside table'))
            continue
        origin = (x << 16, y << 16)
        for child in templates[template_index]['children']:
            child_type_counts[child['type_byte']] = child_type_counts.get(child['type_byte'], 0) + 1
            child_base = dict(**base, child=child['index'], child_type=child['type_byte'],
                               child_mask=child['mask'])
            initially_active = (child['mask'] & (1 << INITIAL_MODE)) != 0
            if not initially_active:
                inactive_children.append(dict(**child_base, initial_mode=INITIAL_MODE,
                                    reason='child mask does not include initial constructor mode 0 '
                                           '(0x5B66A / 0x5E156); not drawn'))
            # Mask 0 never draws. Nonzero masks that miss bit0 keep type0 faces
            # in state_faces only; faces stays the initial mode-0 set.
            if child['mask'] == 0:
                continue
            if child['type_byte'] == 1:
                if initially_active:
                    issues.append(dict(**child_base,
                                        reason='type1 child is exported by map_primitive_geometry '
                                               '(0x5AFA8); this type0 exporter does not emit its vertices '
                                               '(0x5A91D / global 0x22D48 stride 0x37 / call 0xF1A94)'))
                continue
            if child['type_byte'] != 0:
                if initially_active:
                    issues.append(dict(**child_base,
                                        reason=f"unsupported child type_byte={child['type_byte']} "
                                               '(only type0 face-box geometry is proven)'))
                continue
            face_orders = _box_faces(child['bounds'])
            face_target = faces if initially_active else state_faces
            issue_target = issues if initially_active else state_issues
            for fi, surface in enumerate(child['surfaces']):
                rid = surface['resource_id']
                if rid == 0:
                    continue
                indirection = None
                if rid < 0:
                    try:
                        rid, indirection = ms.resolve_resource(rid, texture_blob)
                    except ValueError as exc:
                        issue_target.append(dict(**child_base, face=fi, resource_id=surface['resource_id'],
                                                  reason=f'negative surface id indirection rejected: {exc}'))
                        continue
                image = material_map.get(rid)
                if image is None:
                    issue_target.append(dict(**child_base, face=fi, resource_id=rid,
                                              reason='resource id missing from exported materials bundle '
                                                     '(rejected/unsupported texture format)'))
                    continue
                points = []
                for lx, lz, ly in face_orders[fi]:
                    wx, wy = model((lx << 16, ly << 16), origin, heading, rtable)
                    points.append([wx / 65536.0, lz + height, -(wy / 65536.0)])
                uv = _QUAD_UV_FACE3 if fi == 3 else _QUAD_UV
                face = dict(kind='movable', region=None, placement=placement_id, placement_kind=placement_kind, source_index=pi, template=template_index,
                            child=child['index'], face=fi, child_mask=child['mask'], resource_id=rid,
                            points=points, uv=[list(v) for v in uv], material=image)
                if indirection is not None:
                    face['indirection'] = indirection
                if not initially_active:
                    face['hidden'] = True
                    face['mask'] = child['mask']
                    face['source_bounds'] = list(child['bounds'])
                face_target.append(face)

    summary = dict(placement_kind=placement_kind, source_placements=npl, templates=len(templates), children=parsed['child_count'],
                   faces=len(faces), state_faces=len(state_faces),
                   issues=len(issues), state_issues=len(state_issues),
                   inactive_children=len(inactive_children),
                   constructor_checks=len(placements), constructor_mismatches=len(constructor_mismatches),
                   child_type_counts={str(k): v for k, v in child_type_counts.items()},
                   materials_pending=materials_pending)

    report = dict(
        schema_version=2, placement_kind=placement_kind, placement_stride=stride, area_id=area_id, area_name=area.get('name'), level=area.get('level'),
        source=dict(file=source['file'], sha256=source['sha256'], geometry_key=source['geometry_key']),
        executable_sha256=EXE_HASH, rotation_table_sha256=ROTATION_TABLE_SHA256,
        identity=dict(
            geometry_entry=dict(index=geo_entry['index'], key=geo_entry['key'], size=geo_entry['size']),
            metadata_entry=dict(index=meta_entry['index'], key=meta_entry['key'], size=meta_entry['size'])),
        faces=faces, state_faces=state_faces, materials=material_map, materials_root=str(image_root),
        issues=issues, state_issues=state_issues,
        inactive_children=inactive_children, placements=placement_records, source_templates=templates,
        summary=summary,
        scope='Initial (closed/unmoved) static geometry in `faces`, native world units (X, height, -Y). '
              'Initial mode is constructor constant 0 (0x5B66A / renderer test 0x5E156), so `faces` '
              'includes a type0 child only when mask bit0 is set. Type0 children with a nonzero mask '
              'and bit0 clear are retained in `state_faces` (hidden; same placement rotation, actual '
              'mask and source bounds) and are not activated. Mask 0 stays inactive_children metadata '
              'with no draw. Type1 geometry is map_primitive_geometry, not invented here. Negative '
              'surface ids reuse map_surfaces.resolve_resource on the TEXTURE blob (global 0x22D54, '
              'header 0x20/0x5c). `placements` keeps every source placement for later animation '
              'bindings. Rotation reuses model() from verify_chain_rotation.py. No motion, timing, '
              'trigger or collision behaviour is implemented.')
    require_material_images(image_root, faces + state_faces)
    if out.exists():
        raise ValueError('--out must be a fresh directory')
    out.mkdir(parents=True)
    (out / 'movables.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def _overlaps(left: Path, right: Path) -> bool:
    left, right = left.resolve(), right.resolve()
    return left == right or left in right.parents or right in left.parents


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--material-root', type=Path, required=True)
    parser.add_argument('--re-root', type=Path, required=True,
                        help='RE root whose tools/draracle holds the published constructor and rotation helpers. No default checkout.')
    parser.add_argument('--tools-root', type=Path, required=True,
                        help='Tools directory where this program is installed as tools/export_map_movables.py. '
                             'Its parent must contain docs/game-geometry-profiles.json.')
    parser.add_argument('--area', required=True)
    parser.add_argument('--placement-kind', choices=('movable', 'static_assembly'), required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.out.exists():
        parser.error('--out must be a fresh directory')
    for label, path in (('game', args.game_root), ('material', args.material_root),
                        ('re', args.re_root), ('tools', args.tools_root)):
        if not path.exists():
            parser.error(f'Missing {label} path: {path}')
        if _overlaps(args.out, path):
            parser.error(f'--out overlaps the {label} path')
    try:
        bind(args.tools_root, args.re_root)
    except ValueError as exc:
        parser.error(str(exc))
    report = export_movables(args.game_root, args.area, args.out, material_root=args.material_root,
                              placement_kind=args.placement_kind)
    print(json.dumps(report['summary'], indent=2))


if __name__ == '__main__':
    main()
