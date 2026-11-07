#!/usr/bin/env python3
"""Type1 movable children are attached prop sprites, not polygon meshes.

The 55-byte records reached by 0x5A91D (`[0x22D48] + index*0x37`) are the
metadata template table `map_props.load_templates` already parses (header
dword0 == 18, dword1 == 516, offset at +8, count at +0x40). Each template's
byte 0x2E/0x2F counts 16-byte state records, then 12-byte frame records.
0xF1A14/0xF2B94 only partition that state/frame stream. 0xF1A94 is the shared
prop renderer.

0x5B4E4 calls 0xF1A94 (nine dwords, `add esp, 0x24`). After the callee
prologue the slots are:
  * [ebp+0x14] template pointer (child dword0 after the loader rewrite)
  * [ebp+0x18] 3-dword block: child+4, child+0xC, child+8 (16.16 X, Z, Y)
  * [ebp+0x1C] immediate 0 (frame-clock argument to 0xF2C54/0xF2CC0)
  * [ebp+0x20] child+0x14 (compared with the frame byte at 0xF1CF1)
  * [ebp+0x24] immediate 0 (region pointer)
  * [ebp+0x28] child+0x10 state index, or -1
  * [ebp+0x2C] immediate 1
  * [ebp+0x30] and [ebp+0x34] immediate 0

0xF1DD2 reads template+0x32 bit1. When that bit is set and [ebp+0x24] is
non-null it stores min(255, ceiling-floor). This call's [ebp+0x24] is the
`push 0` at 0x5B500, so the `test eax,eax` / `je 0xF1E07` path always takes
the state record's height byte at [ebx+0x0F]. child+0x14 is not that pointer
and is not a region id.

When the index is -1, 0xF1A94 draws `template[0x2E]` states from the start of
that template (not byte 0x2F). A non-negative index draws that one state.
Initial mode is constructor constant 0 (0x5B66A / 0x5E156): `props` includes
a child only when mask bit0 is set. A nonzero mask with bit0 clear is the
same 55-byte template/state decode into `state_props` (`hidden` true,
`child_mask` kept). Mask 0 stays `inactive_children` metadata and is not
decoded. No later mode is activated.

Sprites, index masks and shadow masks come from `map_props.resolve_templates`
(read-only). Material keys are prefixed `attached_` so they do not collide
with static prop keys for the same descriptor. Bit1 templates use the same
state-height byte as bit1-clear templates, because the region argument is null.
"""
from __future__ import annotations

import hashlib
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import map_materials as mm  # noqa: E402
import map_props as props  # noqa: E402

_TOOLS = Path(__file__).resolve().parents[1]
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))
import re_helper_root
re_helper_root.insert('draracle')
from lol2_verify_draracle_slopes import EXE_HASH  # noqa: E402
from lol2_wall_material_checkpoint import sections  # noqa: E402
from verify_chain_rotation import model  # noqa: E402

require = mm.require
sha256_hex = mm.sha256_hex

DEFAULT_GAME_ROOT = Path('~/lol2_out/museum_capture_20260913/game')
ROTATION_TABLE_PATH = Path('~/lol2_out/draracle_rotation_table_2026-09-11/rotation_table.bin')
ROTATION_TABLE_SHA256 = 'd7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'
MATERIAL_PREFIX = 'attached_'
INITIAL_MODE = 0

# File offsets are VA + 0x37000. Spans are the call/index instructions only.
CODE_SPANS = {
    'index_rewrite': (0x5A91D, 0x5A930),
    'draw_call': (0x5B4E4, 0x5B514),
}


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from('<I', data, offset)[0]


def code_proof(exe: bytes) -> dict:
    require(sha256_hex(exe) == EXE_HASH, 'unsupported or changed executable')
    out = {}
    for name, (start, end) in CODE_SPANS.items():
        raw = exe[start + 0x37000:end + 0x37000]
        out[name] = dict(va=hex(start), end=hex(end), file_offset=start + 0x37000,
                         sha256=hashlib.sha256(raw).hexdigest(), size=len(raw))
    return out


def load_rotation_table(game_root=None) -> tuple:
    if game_root is None:
        data = ROTATION_TABLE_PATH.read_bytes()
    else:
        from lol2_rotation_table import rotation_table
        data = rotation_table(game_root)
    require(sha256_hex(data) == ROTATION_TABLE_SHA256, 'rotation table fixture changed')
    return struct.unpack('<4096i', data)


def _prefixed(materials: dict, animations: dict, visuals: dict, prefix: str = MATERIAL_PREFIX) -> tuple:
    materials = {prefix + key: value for key, value in materials.items()}
    animations = {prefix + key: value for key, value in animations.items()}
    prefixed = {}
    for key, visual in visuals.items():
        row = dict(visual)
        row['material'] = prefix + visual['material']
        prefixed[key] = row
    return materials, animations, prefixed


def prepare_templates(meta: bytes, texture_blob: bytes, out: Path, template_indices=None, material_prefix=MATERIAL_PREFIX) -> dict:
    """Parse metadata templates and decode their sprites once per area."""
    parsed = props.load_templates(meta)
    sec = sections(texture_blob)
    require(sec[3] > sec[2] > 0 and (sec[3] - sec[2]) % 56 == 0, 'descriptor table extent')
    palette_offset = u32(texture_blob, 4)
    require(palette_offset + 768 <= len(texture_blob), 'palette outside blob')
    rgb = mm.rgb_palette(texture_blob[palette_offset:palette_offset + 768], 6)
    out.mkdir(parents=True, exist_ok=True)
    images: dict = {}
    selected = parsed['templates'] if template_indices is None else [
        template for template in parsed['templates'] if template['index'] in template_indices]
    visuals, selector_issues, _extra, deferred, materials, animations = props.resolve_templates(
        selected, texture_blob, sec, rgb, out / 'sprites', out, images)
    materials, animations, visuals = _prefixed(materials, animations, visuals, material_prefix)
    deferred_reason = {row['template']: row['reason'] for row in deferred}
    return dict(parsed=parsed, visuals=visuals, selector_issues=selector_issues,
                deferred_reason=deferred_reason, materials=materials, animations=animations,
                images=images, texture_sha256=sha256_hex(texture_blob), meta_sha256=sha256_hex(meta))


def state_selectors(child: bytes, template: dict) -> tuple[list[int], str | None]:
    """State list 0x5B4E4 passes into 0xF1A94 for one child."""
    index = struct.unpack_from('<i', child, 0x10)[0]
    initial = bytes.fromhex(template['template_hex'])[0x2E]
    if index == -1:
        if initial == 0:
            return [], ('child+0x10 is -1 so 0xF1A94 draws template byte 0x2E states, '
                        'and that count is 0')
        return list(range(initial)), None
    if index < 0 or index >= template['selector_count']:
        return [], f'child+0x10 state {index} outside template selector count {template["selector_count"]}'
    return [index], None


def _anchor(child: bytes, placement: dict, rotation) -> tuple[float, float, float]:
    """Placement origin plus child 16.16 offsets, rotated like type0 vertices."""
    local_x = struct.unpack_from('<i', child, 4)[0]
    local_y = struct.unpack_from('<i', child, 8)[0]
    local_z = struct.unpack_from('<i', child, 12)[0]
    origin = (placement['x'] << 16, placement['y'] << 16)
    world_x, world_y = model((local_x, local_y), origin, placement['heading'], rotation)
    height = placement['height'] + local_z / 65536.0
    return world_x / 65536.0, height, -(world_y / 65536.0)


def props_for_child(child: bytes, placement: dict, prepared: dict, rotation) -> tuple[list, dict | None]:
    """One active type1 child -> billboards, or one issue dict."""
    require(len(child) == 60, 'movable child is 60 bytes')
    base = dict(placement=placement.get('placement'), child=placement.get('child_index'),
                child_type=child[59], child_mask=u32(child, 48),
                template=u32(child, 0),
                state_index=struct.unpack_from('<i', child, 0x10)[0],
                child_hex=child.hex())
    if child[59] != 1:
        return [], dict(**base, reason=f'child type_byte={child[59]} is not an attached prop')
    mask = u32(child, 48)
    if mask == 0:
        return [], dict(**base, reason='child mask does not include initial constructor mode 0')
    initially_active = (mask & (1 << INITIAL_MODE)) != 0
    template_index = u32(child, 0)
    templates = prepared['parsed']['templates']
    if template_index >= len(templates):
        return [], dict(**base, reason='template index outside metadata template table')
    template = templates[template_index]
    if template_index in prepared['deferred_reason']:
        return [], dict(**base, reason=prepared['deferred_reason'][template_index])
    selectors, reason = state_selectors(child, template)
    if reason:
        return [], dict(**base, reason=reason)
    anchor = _anchor(child, placement, rotation)
    rows = []
    for selector in selectors:
        key = (template_index, selector)
        if key in prepared['selector_issues']:
            return [], dict(**base, selector=selector, reason=prepared['selector_issues'][key])
        visual = prepared['visuals'].get(key)
        if visual is None:
            return [], dict(**base, selector=selector, reason='selector has no resolved visual')
        # 0x5B500 pushes 0 into F1A94's region slot. 0xF1DD2 then uses state+0x0F.
        top = visual['state_height'] - visual['top_trim']
        if visual['right'] <= visual['left'] or top <= visual['bottom']:
            return [], dict(**base, selector=selector, reason='degenerate sprite bounds')
        left, right, bottom = visual['left'], visual['right'], visual['bottom']
        ax, ay, az = anchor
        row = dict(
            **base, selector=selector, position=[ax, ay, az],
            material=visual['material'], width=visual['width'], height=visual['height'],
            left=left, right=right, bottom=bottom, top=top,
            animated=visual['material'] in prepared['animations'],
            points=[[ax + left, ay + bottom, az], [ax + right, ay + bottom, az],
                    [ax + right, ay + top, az], [ax + left, ay + top, az]],
            state_offset=visual['state_offset'], state_hex=visual['state_hex'],
            frame_offset=visual['frame_offset'], frame_hex=visual['frame_hex'],
            local_fixed=[struct.unpack_from('<i', child, off)[0] for off in (4, 8, 12)])
        for field in ('frame_hexes', 'frame_flags_list', 'source_frame_count',
                      'state_frames', 'later_state_frames'):
            if field in visual:
                row[field] = visual[field]
        if not initially_active:
            row['hidden'] = True
        rows.append(row)
    return rows, None


def export_type1_records(meta: bytes, texture_blob: bytes, records: list[dict], out: Path,
                         rotation=None, exe: bytes | None = None, material_prefix=MATERIAL_PREFIX) -> dict:
    """Export initial type1 attached props for raw 60-byte children.

    Each record supplies `child` (60 bytes) and placement `x`, `y`, `height`,
    `heading`, plus optional `placement` and `child` indexes.
    """
    selected = {u32(record['child'], 0) for record in records if u32(record['child'], 48) != 0}
    prepared = prepare_templates(meta, texture_blob, out, selected, material_prefix)
    if rotation is None:
        rotation = load_rotation_table()
    rendered, state_props, issues, state_issues, nonvisual, inactive = [], [], [], [], [], []
    for record in records:
        rows, issue = props_for_child(record['child'], record, prepared, rotation)
        if rows:
            if rows[0].get('hidden'):
                state_props.extend(rows)
            else:
                rendered.extend(rows)
        elif issue:
            hidden_gap = (issue['child_mask'] & 1) == 0 and issue['child_mask'] != 0
            if issue['reason'] == 'child mask does not include initial constructor mode 0':
                inactive.append(issue)
            elif issue['reason'].startswith('nonvisual descriptor') and not hidden_gap:
                nonvisual.append(issue)
            elif hidden_gap:
                state_issues.append(issue)
            else:
                issues.append(issue)
    report = dict(
        schema_version=1,
        meta_sha256=prepared['meta_sha256'],
        texture_sha256=prepared['texture_sha256'],
        executable_sha256=EXE_HASH if exe is None else sha256_hex(exe),
        code=code_proof(exe) if exe is not None else None,
        template_count=len(prepared['parsed']['templates']),
        template_states=prepared['parsed']['state_count'],
        template_frames=prepared['parsed']['frame_count'],
        props=rendered, state_props=state_props, issues=issues, state_issues=state_issues,
        nonvisual_props=nonvisual, inactive_children=inactive,
        materials=prepared['materials'], animations=prepared['animations'],
        sprites=[prepared['images'][key] for key in sorted(prepared['images'])],
        summary=dict(records=len(records), props=len(rendered), state_props=len(state_props),
                     issues=len(issues), state_issues=len(state_issues),
                     nonvisual=len(nonvisual), inactive=len(inactive)),
        scope='Initial mode 0 type1 children in `props`. Anchor is placement (x,y,height,heading) '
              'plus child fixed offsets +4/+8/+12. State index is child+0x10; -1 draws the '
              'first template[0x2E] states. Nonzero masks with bit0 clear use that same decode '
              'in `state_props` (hidden, child_mask retained) and are not activated. Mask 0 stays '
              'inactive_children metadata. 0x5B4E4 passes a null region pointer, so template '
              'flags bit1 still uses the state height byte. Material keys use the attached_ prefix. '
              'No polygon substitute and no motion.')
    out.mkdir(parents=True, exist_ok=True)
    (out / 'type1_props.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def area_records(game_root: Path, area_id: str, placement_kind: str = 'movable') -> tuple[bytes, bytes, list[dict], dict]:
    """Metadata, texture blob, and every movable child with its placement."""
    inventory = mm.load_inventory()
    area = mm.area_by_id(inventory, area_id)
    source = area['source']
    mix = (game_root / source['file']).read_bytes()
    require(sha256_hex(mix) == source['sha256'], f'{area_id}: unsupported or changed archive')
    identity = mm.identify_entries(mix, mm.parse_mix(mix), source['geometry_key'])
    meta_entry = identity['metadata_entry']
    meta = mix[meta_entry['offset']:meta_entry['offset'] + meta_entry['size']]
    texture, _decode = mm.decode_lzo_container(mix, identity['texture_entry'])
    import export_map_movables as movables
    movables.bind(_TOOLS, re_helper_root.root())
    movable = movables.load_movable_templates(meta)
    geo_entry = identity['geometry_entry']
    geo = mix[geo_entry['offset']:geo_entry['offset'] + geo_entry['size']]
    po, placements = movables.placement_table(geo, placement_kind)
    count = len(placements)
    records = []
    for index, raw in enumerate(placements):
        x, y, heading, height = struct.unpack_from('<hhHh', raw)
        template_index = raw[32]
        if template_index >= len(movable['templates']):
            continue
        for child in movable['templates'][template_index]['children']:
            records.append(dict(
                placement=movables.placement_identity(index, placement_kind), placement_kind=placement_kind, child_index=child['index'], x=x, y=y, heading=heading, height=height,
                child=bytes.fromhex(child['raw_hex'])))
    return meta, texture, records, dict(source=source, meta_entry=meta_entry, geo_entry=geo_entry,
                                         placement_offset=po, placement_count=count)


def export_area(game_root: Path, area_id: str, out: Path, *, placement_kind: str = 'movable') -> dict:
    exe = (game_root / 'LOLG.DAT').read_bytes()
    code_proof(exe)
    rotation = load_rotation_table(game_root)
    meta, texture, records, identity = area_records(game_root, area_id, placement_kind)
    type1 = [row for row in records if row['child'][59] == 1]
    report = export_type1_records(meta, texture, type1, out, exe=exe, rotation=rotation,
                                  material_prefix='static_attached_' if placement_kind == 'static_assembly' else MATERIAL_PREFIX)
    report['placement_kind'] = placement_kind
    report['area_id'] = area_id
    report['source'] = dict(file=identity['source']['file'], sha256=identity['source']['sha256'])
    report['metadata_entry'] = dict(index=identity['meta_entry']['index'],
                                     offset=identity['meta_entry']['offset'],
                                     size=identity['meta_entry']['size'],
                                     template_offset=u32(meta, 8),
                                     template_count=u32(meta, 0x40))
    report['summary']['source_children'] = len(records)
    report['summary']['type1_children'] = len(type1)
    (out / 'type1_props.json').write_text(json.dumps(report, indent=2) + '\n')
    return report
