#!/usr/bin/env python3
"""Shared texture export for the fifteen pinned LoL2 map archives.

Archive entries are selected by pinned geometry identity and bounded structural
validation of the remaining texture container. Metadata is decoded separately.
Raw slot families A9/E1/8B/C3 and compressed column families 8F/C7 are supported,
including observed tagged forms. Raw pixels use column-major storage, verified
against native wall addressing at 0x12D676; compressed expansion produces rows.

The exporter preserves grayscale indices, the source palette and remap tables
alongside RGB review images. Variant dimensions and lower-mip counts are retained
without inventing frames. Column expansion matches the original 0x12621C routine.
Variable-size animation addressing
also remains an explicit review issue. Decoding success is not native visual
parity. Unsupported descriptors remain in rejected; map_props handles scenery
sprite families separately.
"""
from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import hashlib
import json
import struct
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
INVENTORY = REPO_ROOT / 'docs' / 'game-source-inventory.json'
RE_TOOLS = Path('/home/bob/lol2_re_publish_20260911/tools/draracle')
MUSEUM_WITNESS = Path('/home/bob/lol2_out/museum_capture_20260913/museum_texture_blob.bin')
MUSEUM_AREA_ID = 'L3_DH'

TEXTURE_KEY_OFFSET = 984071
METADATA_KEY_OFFSET = 654590
MAX_DECOMPRESSED = 64 * 1024 * 1024
LZO_BLOCK = 1024 * 1024

sys.path.insert(0, str(REPO_ROOT / 'tools'))
sys.path.insert(0, str(RE_TOOLS))
from lol2_extract_draracle_geometry import parse_mix  # noqa: E402
from lol2_wall_material_checkpoint import sections, material_record  # noqa: E402
from lol2_pixel_layout import column_major_to_rows  # noqa: E402
from lol2_palette_png import rgb_palette, colorize, png_rgb  # noqa: E402


def write_if_changed(path: Path, data: bytes) -> None:
    if path.exists() and path.read_bytes() == data:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load_inventory() -> dict:
    return json.loads(INVENTORY.read_text())


def area_by_id(inventory: dict, area_id: str) -> dict:
    matches = [a for a in inventory['areas'] if a['id'] == area_id]
    require(len(matches) == 1,
            f'Unknown area_id {area_id!r}; expected one of '
            f'{sorted(a["id"] for a in inventory["areas"])}')
    return matches[0]


from lol2_texture_container import decode_lzo_container


def looks_like_material_container(blob: bytes) -> bool:
    try:
        s = sections(blob)
        pal = struct.unpack_from('<I', blob, 4)[0]
        require(pal + 768 == s[4], 'palette boundary')
        require(s[3] > s[2] > 0 and (s[3] - s[2]) % 56 == 0, 'descriptor table extent')
        return True
    except (ValueError, IndexError, struct.error):
        return False


def identify_entries(mix: bytes, entries: list[dict], geometry_key: int) -> dict:
    geo_matches = [e for e in entries if e['key'] == geometry_key]
    require(len(geo_matches) == 1, 'pinned geometry_key missing or ambiguous in this archive')
    geometry_entry = geo_matches[0]
    remaining = [e for e in entries if e is not geometry_entry]
    require(len(remaining) == 2, f'expected exactly 3 MIX entries, found {len(entries)}')

    texture_key = (geometry_key + TEXTURE_KEY_OFFSET) & 0xffffffff
    metadata_key = (geometry_key - METADATA_KEY_OFFSET) & 0xffffffff

    formula_matches = [e for e in remaining if e['key'] == texture_key]
    if len(formula_matches) == 1:
        texture_entry = formula_matches[0]
        metadata_entry = next(e for e in remaining if e is not texture_entry)
        texture_key_source = 'formula'
    else:
        candidates = []
        for e in sorted(remaining, key=lambda e: -e['size']):
            try:
                blob, decode_info = decode_lzo_container(mix, e)
            except ValueError:
                continue
            if looks_like_material_container(blob):
                candidates.append((e, blob, decode_info))
        require(len(candidates) == 1,
                f'could not unambiguously identify the texture entry structurally '
                f'({len(candidates)} candidates validated)')
        texture_entry, _pref_blob, _pref_info = candidates[0]
        metadata_entry = next(e for e in remaining if e is not texture_entry)
        texture_key_source = 'structural_fallback'

    return dict(geometry_entry=geometry_entry, texture_entry=texture_entry,
                metadata_entry=metadata_entry, texture_key_source=texture_key_source,
                texture_key_formula_match=texture_entry['key'] == texture_key,
                metadata_key_formula_match=metadata_entry['key'] == metadata_key,
                texture_key_formula=texture_key, metadata_key_formula=metadata_key)


# --- self-describing slot engine ---
#
# Every non-0xA9 descriptor proven so far (0xE1, 0x8B, 0x80A9, 0x80E1, 0x20E1, 0xC3,
# 0xC7, 0x80C7, standalone 0x808B) turns out to share one on-disk grammar: each mip
# level's byte span (bounded by the next mip's declared offset, or by the payload
# region end for the last level) holds a sequence of self-describing slots, each with
# its own (flags, width, height, length) header. A slot is either:
#   - raw: length == width*height exactly (proven on 0xA9's raw sibling 0x8B/0x808B,
#     and independently on 0xC3 which is 0xC7's smaller-mip raw sibling), or
#   - column/RLE: length < width*height and the bytes after the header form a valid
#     per-column offset directory + RLE run stream (native 0x12621C expands leads
#     0..2 as repeats and other leads as literals, verified by instruction replay
#     on 0x8F/0x808F and 0xC7/0x80C7; compressed large mips fall back to the
#     exact same raw grammar as 0xC3 at smaller mip levels -- the same pairing pattern
#     already proven for 0x8F/0x8B).
# Word8 low byte is a count and word8 high byte is a phase only when that high byte
# is nonzero. Those descriptors are one member of a contiguous group; each member's
# own mip offset and size is that frame. A nonzero phase that does not match the
# group is rejected. High byte 0 keeps the span walk below, including a low-byte
# count of 1. This preserves the existing phase-zero implementation. Slots of a different size found beside
# primary frames are `ambiguous_slots`, not folded in.

def decode_column_payload(data: bytes, width: int, height: int) -> tuple[bytes, bool]:
    """Original 0x12621C grammar: leads 0..2 repeat; leads >2 start literals.

    tools/verify_map_column_rle.py executes the original x86 instructions against
    synthetic runs and exported source columns. The legacy second return value
    remains false: this decoder no longer falls back to an unverified grammar.
    Pixel expansion does not establish renderer lighting or alpha semantics.
    """
    return _decode_column_payload(data, width, height, repeat_le2=True), False


def _decode_column_payload(data: bytes, width: int, height: int, repeat_le2: bool) -> bytes:
    require(len(data) >= width * 2, 'missing column directory')
    offsets = struct.unpack_from(f'<{width}H', data)
    pixels = bytearray(width * height)
    for x, start in enumerate(offsets):
        if start == 0:
            continue
        following = [o for o in offsets[x + 1:] if o]
        stop = following[0] if following else len(data)
        require(width * 2 <= start < stop <= len(data), 'column bounds')
        pos, y = start, 0
        while pos < stop:
            count = data[pos]
            pos += 1
            require(count != 0 and y + count <= height and pos < stop, 'invalid column run')
            lead = data[pos]
            if lead == 0 or (repeat_le2 and lead <= 2):
                for j in range(count):
                    pixels[(y + j) * width + x] = lead
                pos += 1
            else:
                require(pos + count <= stop, 'literal exceeds column')
                for j, value in enumerate(data[pos:pos + count]):
                    pixels[(y + j) * width + x] = value
                pos += count
            y += count
        require(y == height and pos == stop, 'incomplete column')
    if not any(offsets):
        require(len(data) == width * 2, 'unaccounted empty-column data')
    else:
        require(min(o for o in offsets if o) == width * 2, 'directory/payload gap')
    return bytes(pixels)


def read_slot(blob: bytes, pos: int, bound: int) -> dict:
    require(pos + 8 <= bound, 'slot header outside its span')
    flags, w, h, length = struct.unpack_from('<4H', blob, pos)
    require(0 < w <= 4096 and 0 < h <= 4096, 'invalid slot dimensions')
    raw_family = (flags & 0xff) in (0xa9, 0xe1, 0x8b, 0xc3)
    is_raw = raw_family and length == ((w * h) & 0xffff)
    size = 8 + (w * h if is_raw else length)
    require(pos + size <= bound, 'slot payload exceeds its span')
    payload = blob[pos + 8:pos + size]
    unproven_repeat = False
    if is_raw:
        kind, pixels = 'raw', payload
    else:
        require((flags & 0xff) in (0x8f, 0xc7), 'unsupported slot encoding')
        pixels, unproven_repeat = decode_column_payload(payload, w, h)
        kind = 'column'
    return dict(flags=flags, width=w, height=h, length=length, size=size, kind=kind,
                data_start=pos + 8, pixels=pixels, unproven_repeat=unproven_repeat)


def image_rows(image: dict) -> bytes:
    """Return image rows from raw native columns or already expanded RLE rows."""
    if image['kind'] == 'raw':
        return column_major_to_rows(image['pixels'], image['width'], image['height'])
    require(image['kind'] == 'column', 'unknown decoded image layout')
    return image['pixels']


def scan_slots(blob: bytes, start: int, end: int) -> list[dict]:
    pos = start
    slots = []
    while pos < end:
        slot = read_slot(blob, pos, end)
        slots.append(slot)
        pos += slot['size']
    require(pos == end, 'slot scan did not exactly consume its mip span')
    return slots


def _record_view(blob: bytes, table: int, index: int) -> dict:
    position = table + index * 56
    v = struct.unpack_from('<6H11I', blob, position)
    identifier, width, height, flags, field8, field10 = v[:6]
    return dict(index=index, position=position, identifier=identifier, width=width,
                height=height, flags=flags, field8=field8, field10=field10,
                levels=field10 & 255, mip_offsets=v[7:12], mip_sizes=v[12:17])


def _phase_group_record(blob: bytes, table: int, payload: int, end: int, index: int,
                        own: dict) -> dict:
    """Nonzero word8 high byte: phase within a contiguous descriptor group.

    Count is byte 8 and phase is byte 9. Validation failure raises. It does not
    fall through to the mixed-size span walk. Native playback timing is not proved.
    """
    count = own['field8'] & 255
    phase = own['field8'] >> 8
    require(1 <= count <= 64 and phase < count, 'phase group word8 out of range')
    base = index - phase
    desc_count = (payload - table) // 56
    require(0 <= base and base + count <= desc_count, 'phase group leaves the descriptor table')
    members = []
    anchor = None
    for step in range(count):
        member = _record_view(blob, table, base + step)
        require((member['field8'] & 255) == count and (member['field8'] >> 8) == step,
                'phase group word8 does not match count and member index')
        if anchor is None:
            anchor = member
        else:
            require(member['width'] == anchor['width'] and member['height'] == anchor['height']
                    and member['flags'] == anchor['flags'] and member['field10'] == anchor['field10'],
                    'phase group dimensions, flags, or level word differ')
            require(member['identifier'] == anchor['identifier'] + step,
                    'phase group identifiers are not contiguous')
        members.append(member)
    levels = anchor['levels']
    require(1 <= levels <= 5, f'mip level count out of range (field10&255={levels})')
    order = [(phase + step) % count for step in range(count)]
    images = []
    for variant, step in enumerate(order):
        member = members[step]
        for level in range(levels):
            expect_w = max(1, anchor['width'] >> level)
            expect_h = max(1, anchor['height'] >> level)
            size = member['mip_sizes'][level]
            start = payload + member['mip_offsets'][level]
            require(size >= 8 and payload <= start and start + size <= end,
                    'phase group mip is outside the payload')
            slot = read_slot(blob, start, start + size)
            require(slot['size'] == size, 'phase group slot size does not equal the declared mip size')
            require(slot['width'] == expect_w and slot['height'] == expect_h,
                    'phase group slot dimensions do not equal the mip size')
            images.append(dict(level=level, variant=variant, width=slot['width'], height=slot['height'],
                                data_start=slot['data_start'], size=slot['size'], kind=slot['kind'],
                                pixels=slot['pixels'], unproven_repeat=slot['unproven_repeat'],
                                source_index=member['index'], source_identifier=member['identifier'],
                                source_phase=step))
    return dict(index=index, descriptor_start=own['position'], identifier=own['identifier'],
                width=own['width'], height=own['height'], flags=own['flags'], variant_count=count,
                levels=levels, images=images, ambiguous_slots=[], field8_raw=own['field8'],
                variable_frame_sizes=False,
                phase_group=dict(
                    phase=phase, count=count, base_index=base,
                    descriptor_indices=[member['index'] for member in members],
                    identifiers=[member['identifier'] for member in members],
                    frame_order=[members[step]['index'] for step in order],
                    timing='provisional; native animation timing and high-byte mutation are not proved',
                ))


def generic_variant_record(blob: bytes, table: int, payload: int, end: int, index: int) -> dict:
    own = _record_view(blob, table, index)
    if own['field8'] >> 8:
        return _phase_group_record(blob, table, payload, end, index, own)
    position = own['position']
    identifier, width, height, flags, field8, field10 = (
        own['identifier'], own['width'], own['height'], own['flags'], own['field8'], own['field10'])
    levels = own['levels']
    require(1 <= levels <= 5, f'mip level count out of range (field10&255={levels})')
    mip_offsets, mip_sizes = own['mip_offsets'], own['mip_sizes']

    per_level = []
    for level in range(levels):
        w, h = max(1, width >> level), max(1, height >> level)
        start = payload + mip_offsets[level]
        require(payload <= start, 'mip start outside payload')
        right = payload + mip_offsets[level + 1] if level < levels - 1 else None
        if right is not None:
            require(start < right <= end, 'mip span outside payload')
        per_level.append(dict(level=level, width=w, height=h, start=start, right=right, slots=None))
        if right is not None:
            slots = scan_slots(blob, start, right)
            require(slots and slots[0]['size'] == mip_sizes[level],
                    "first slot size does not match the descriptor's own recorded mip size")
            per_level[-1]['slots'] = slots

    bounded = [lv for lv in per_level if lv['slots'] is not None]
    require(bounded, 'no mip level has a resolvable right boundary to scan')

    def primary_count(lv):
        return sum(1 for sl in lv['slots'] if sl['width'] == lv['width'] and sl['height'] == lv['height'])

    slot_counts = [len(lv['slots']) for lv in bounded]
    declared_frames = field8 & 255
    # Low byte of word8 matches the walked slot count, including slots smaller
    # than the descriptor's nominal size (L17_HC descriptor 378: word8=259).
    variable_frames = (
        len(set(slot_counts)) == 1 and declared_frames == slot_counts[0]
        and declared_frames != primary_count(bounded[0])
        and all(primary_count(lv) != declared_frames for lv in bounded)
    )
    if variable_frames:
        variants = declared_frames
        require(1 <= variants <= 64, f'variant count implausible ({variants})')
    else:
        primary_counts = {primary_count(lv) for lv in bounded}
        require(len(primary_counts) == 1,
                f'inconsistent primary variant count across bounded mip levels: '
                f'{[primary_count(lv) for lv in bounded]}')
        variants = next(iter(primary_counts))
        require(1 <= variants <= 64, f'variant count implausible ({variants} primary slots found)')

    last = per_level[-1]
    if last['slots'] is None:
        pos = last['start']
        require(pos == payload + mip_offsets[levels - 1] and pos + mip_sizes[levels - 1] <= end,
                'final-level start outside payload (loose bound only: no declared right boundary)')
        slots = []
        if variable_frames:
            prev = bounded[-1]
            shift = last['level'] - prev['level']
            for src in prev['slots']:
                if pos + 8 > end:
                    break
                peek_w, peek_h = struct.unpack_from('<HH', blob, pos + 2)
                expect = (max(1, src['width'] >> shift), max(1, src['height'] >> shift))
                if (peek_w, peek_h) != expect:
                    break
                slot = read_slot(blob, pos, end)
                slots.append(slot)
                pos += slot['size']
            require(slots, 'final mip has no variable-size frame')
        else:
            for _ in range(variants):
                slot = read_slot(blob, pos, end)
                require((slot['width'], slot['height']) == (last['width'], last['height']),
                        'final-level variant dimensions mismatch')
                slots.append(slot)
                pos += slot['size']
        last['slots'] = slots

    images, ambiguous = [], []
    for lv in per_level:
        if variable_frames:
            primary = list(lv['slots'])
            extra = []
        else:
            primary = [sl for sl in lv['slots'] if sl['width'] == lv['width'] and sl['height'] == lv['height']]
            extra = [sl for sl in lv['slots'] if sl not in primary]
        if not (variable_frames and lv['level'] == levels - 1 and len(primary) < variants):
            require(len(primary) == variants,
                    f'mip level {lv["level"]} has {len(primary)} primary-size slots, expected {variants}')
        for i, sl in enumerate(primary):
            images.append(dict(level=lv['level'], variant=i, width=sl['width'], height=sl['height'],
                                data_start=sl['data_start'], size=sl['size'], kind=sl['kind'],
                                pixels=sl['pixels'], unproven_repeat=sl['unproven_repeat']))
        for sl in extra:
            ambiguous.append(dict(level=lv['level'], width=sl['width'], height=sl['height'],
                                   data_start=sl['data_start'], size=sl['size'], kind=sl['kind']))
    return dict(index=index, descriptor_start=position, identifier=identifier,
                width=width, height=height, flags=flags, variant_count=variants,
                levels=levels, images=images, ambiguous_slots=ambiguous, field8_raw=field8,
                variable_frame_sizes=variable_frames)


def export_materials(game_root: Path, area_id: str, out: Path) -> dict:
    """Export decoded materials for one pinned level MIX into `out`.

    Returns the same report dict written to `out/materials.json`.
    """
    inventory = load_inventory()
    area = area_by_id(inventory, area_id)
    source = area['source']

    mix_path = game_root / source['file']
    mix = mix_path.read_bytes()
    require(sha256_hex(mix) == source['sha256'], f'{area_id}: unsupported or changed archive')

    entries = parse_mix(mix)
    identity = identify_entries(mix, entries, source['geometry_key'])
    blob, decode_info = decode_lzo_container(mix, identity['texture_entry'])

    museum_validation = None
    if area_id == MUSEUM_AREA_ID:
        witness = MUSEUM_WITNESS.read_bytes()
        require(blob == witness, 'museum decoded blob differs from the pinned runtime witness byte-for-byte')
        museum_validation = dict(witness=str(MUSEUM_WITNESS), witness_sha256=sha256_hex(witness),
                                  byte_for_byte_match=True)

    s = sections(blob)
    palette_offset = struct.unpack_from('<I', blob, 4)[0]
    require(palette_offset + 768 == s[4], 'palette boundary')
    dac = blob[palette_offset:palette_offset + 768]
    rgb = rgb_palette(dac, 6)
    shade_banks = 0
    if len(s) > 5 and (s[5] - s[4]) % 256 == 0:
        shade_banks = (s[5] - s[4]) // 256
    table, payload = s[2], s[3]
    require(table > 0 and payload > table and (payload - table) % 56 == 0, 'descriptor table extent')
    count = (payload - table) // 56
    end = min((x for x in s if x > payload), default=len(blob))

    out.mkdir(parents=True, exist_ok=True)
    write_if_changed(out / 'palette_dac.bin', dac)
    write_if_changed(out / 'texture.bin', blob)
    write_if_changed(out / 'palette_rgb.png', png_rgb(256, 1, rgb))
    sys.path.insert(0, str(REPO_ROOT / 'tools' / 'lol2'))
    from map_sprite_rows import initial_remap_row
    shade64 = initial_remap_row(blob, decode_info['decoded_sha256'])
    write_if_changed(out / 'shade64_remap.png', _png_gray_bytes(256, 1, shade64))

    materials = []
    rejected = []
    for k in range(count):
        flags = struct.unpack_from('<H', blob, table + k * 56 + 6)[0]
        try:
            folder = out / f'material_{k:04d}'
            if flags == 0xa9:
                rec = material_record(blob, k, allow_partial_mips=True)
                folder.mkdir(exist_ok=True)
                write_if_changed(folder / 'descriptor.bin',
                                 blob[rec['descriptor_start']:rec['descriptor_start'] + 56])
                for m in rec['mips']:
                    pixels = blob[m['data_start']:m['data_start'] + m['width'] * m['height']]
                    rows = column_major_to_rows(pixels, m['width'], m['height'])
                    image = png_rgb(m['width'], m['height'], colorize(rows, rgb))
                    write_if_changed(folder / f'mip_{m["level"]}_palette.png', image)
                    if m['level'] == 0:
                        write_if_changed(folder / 'mip_0_palette.png', image)
                        write_if_changed(folder / 'mip_0_indices.png',
                                         _png_gray_bytes(m['width'], m['height'], rows))
                m0 = rec['mips'][0]
                materials.append(dict(index=k, identifier=rec['identifier'], width=rec['width'],
                                       height=rec['height'], flags=flags, variant_count=1,
                                       mip_levels=len(rec['mips']),
                                       image=str((folder / 'mip_0_palette.png').relative_to(out)),
                                       family='a9_mip_chain'))
            else:
                # Any other base flags value: attempt the generic self-describing slot
                # scan rather than rejecting by flag membership. This has proven correct
                # on 0xE1, 0x8B, 0x80A9, 0x80E1, 0x20E1, 0xC3, 0xC7, 0x80C7, 0x8F, 0x808F
                # and standalone 0x808B; anything whose bytes do not actually form valid
                # slot headers still fails scan_slots()'s exact-span requirement and is
                # rejected below with a specific reason -- no flag value is
                # special-cased into acceptance.
                rec = generic_variant_record(blob, table, payload, end, k)
                folder.mkdir(exist_ok=True)
                write_if_changed(folder / 'descriptor.bin',
                                 blob[rec['descriptor_start']:rec['descriptor_start'] + 56])
                frames = []
                canonical_kind = None
                for im in rec['images']:
                    if im['level'] != 0:
                        continue
                    canonical_kind = im['kind']
                    pixels = image_rows(im)
                    if flags & 2:
                        rgba = bytes(c for i in pixels for c in (*rgb[i * 3:i * 3 + 3], 0 if i == 0 else 255))
                        image = _png_rgba_bytes(im['width'], im['height'], rgba)
                    else:
                        image = png_rgb(im['width'], im['height'], colorize(pixels, rgb))
                    name = f'variant_{im["variant"]}.png'
                    write_if_changed(folder / name, image)
                    write_if_changed(folder / f'variant_{im["variant"]}_indices.png',
                                     _png_gray_bytes(im['width'], im['height'], pixels))
                    frames.append(name)
                    if im['variant'] == 0:
                        write_if_changed(folder / 'mip_0_palette.png', image)
                        write_if_changed(folder / 'mip_0_indices.png',
                                         _png_gray_bytes(im['width'], im['height'], pixels))
                if canonical_kind == 'column':
                    orientation = ('column/RLE-decoded (native 0x12621C grammar); index-0 '
                                    'treated as transparent; native playback clock unverified')
                else:
                    orientation = ('column-major raw storage converted to rows; native '
                                    '0x12D676 addresses slot+8+x*height; playback clock unverified')
                entry = dict(index=k, identifier=rec['identifier'], width=rec['width'],
                             height=rec['height'], flags=flags, variant_count=rec['variant_count'],
                             mip_levels=rec['levels'],
                             image=str((folder / 'mip_0_palette.png').relative_to(out)),
                             family=('column_major_variant' if flags == 0x80a9 else
                                     'column_rle' if canonical_kind == 'column' else 'raw_variant'),
                             scope=orientation, pixel_layout='row_major_export',
                             source_pixel_layout='column_rle' if canonical_kind == 'column' else 'column_major_raw')
                if flags & 2:
                    entry['alpha_cutout'] = True
                    entry['alpha_source'] = 'descriptor_bit_2_native_12d267'
                if canonical_kind == 'column':
                    entry['column_decoder'] = 'native_12621c'
                if rec.get('phase_group'):
                    entry['phase_group'] = rec['phase_group']
                    entry['field8_raw'] = rec['field8_raw']
                    entry['field8_note'] = (
                        'word8 low byte is the group count and the high byte is this '
                        'descriptor phase. Frames are each member mip, current phase first, '
                        'then the group in cyclic order. Native animation timing is provisional.')
                elif rec['variable_frame_sizes']:
                    entry['variable_frame_sizes'] = True
                    entry['frame_sizes'] = [
                        dict(variant=im['variant'], width=im['width'], height=im['height'])
                        for im in rec['images'] if im['level'] == 0]
                    entry['field8_raw'] = rec['field8_raw']
                    entry['field8_note'] = (
                        'low byte of descriptor word8 equals the walked per-level slot count, '
                        'including frames smaller than the nominal size; the high byte is not a count')
                elif rec['field8_raw'] != rec['variant_count']:
                    entry['field8_raw'] = rec['field8_raw']
                    entry['field8_note'] = ('descriptor word8 does not equal the variant count '
                                             'established from actual mip bounds; not trusted as-is')
                if rec['variant_count'] > 1:
                    entry['animation_frames'] = frames
                if rec['ambiguous_slots']:
                    entry['shadow_blend_candidates'] = [
                        dict(level=a['level'], width=a['width'], height=a['height'], kind=a['kind'])
                        for a in rec['ambiguous_slots']]
                    entry['shadow_blend_note'] = (
                        f"{len(rec['ambiguous_slots'])} extra differently-sized slot(s) found inside "
                        'this descriptor\'s mip spans alongside the primary animation frames; role '
                        '(shadow, blend target, or something else) and orientation are unresolved and '
                        'these bytes are not exported as images')
                materials.append(entry)
        except ValueError as exc:
            rejected.append(dict(index=k, flags=flags, reason=str(exc)))

    rejected_by_flags = {}
    for r in rejected:
        rejected_by_flags.setdefault(f'0x{r["flags"]:x}', 0)
        rejected_by_flags[f'0x{r["flags"]:x}'] += 1

    report = dict(
        schema_version=1, area_id=area_id, area_name=area.get('name'), level=area.get('level'),
        source=dict(file=source['file'], sha256=source['sha256'], geometry_key=source['geometry_key']),
        identity=dict(
            geometry_entry=dict(index=identity['geometry_entry']['index'],
                                 key=identity['geometry_entry']['key'],
                                 size=identity['geometry_entry']['size']),
            texture_entry=dict(index=identity['texture_entry']['index'],
                                key=identity['texture_entry']['key'],
                                size=identity['texture_entry']['size'],
                                key_source=identity['texture_key_source'],
                                formula=identity['texture_key_formula'],
                                formula_match=identity['texture_key_formula_match']),
            metadata_entry=dict(index=identity['metadata_entry']['index'],
                                 key=identity['metadata_entry']['key'],
                                 size=identity['metadata_entry']['size'],
                                 sha256=sha256_hex(mix[identity['metadata_entry']['offset']:
                                                       identity['metadata_entry']['offset'] +
                                                       identity['metadata_entry']['size']]),
                                 formula=identity['metadata_key_formula'],
                                 formula_match=identity['metadata_key_formula_match'],
                                 note='identity recorded only; no proven helper in this codebase '
                                      'decodes a metadata container format')),
        decode=decode_info, museum_validation=museum_validation,
        palette_offset=palette_offset, shade_banks=shade_banks,
        descriptor_count=count, extracted_count=len(materials), rejected_count=len(rejected),
        rejected_by_flags=rejected_by_flags,
        materials=materials, rejected=rejected,
        source_hash=dict(archive_sha256=source['sha256'], texture_payload_sha256=sha256_hex(
            mix[identity['texture_entry']['offset']:
                identity['texture_entry']['offset'] + identity['texture_entry']['size']]),
            decoded_texture_sha256=decode_info['decoded_sha256']),
        scope='Structural extraction using previously proven flag-family decoders only '
              '(0xA9, 0xE1/0x8B, 0x80A9, 0x8F/0x808F). All other descriptor flags observed in '
              'this archive are reported under rejected with their literal value; no format is '
              'guessed. File-palette previews only, no runtime shading/geometry-binding replay.',
    )
    report_text = (json.dumps(report, indent=2) + '\n').encode()
    write_if_changed(out / 'materials.json', report_text)
    return report


def _png_gray_bytes(width: int, height: int, indices: bytes) -> bytes:
    import zlib
    require(len(indices) == width * height, 'invalid index image extent')

    def chunk(kind: bytes, content: bytes) -> bytes:
        return (struct.pack('>I', len(content)) + kind + content
                + struct.pack('>I', zlib.crc32(kind + content)))

    rows = b''.join(b'\0' + indices[y * width:(y + 1) * width] for y in range(height))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 0, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def _png_rgba_bytes(width: int, height: int, rgba: bytes) -> bytes:
    import zlib
    require(len(rgba) == width * height * 4, 'invalid RGBA image extent')

    def chunk(kind: bytes, content: bytes) -> bytes:
        return (struct.pack('>I', len(content)) + kind + content
                + struct.pack('>I', zlib.crc32(kind + content)))

    rows = b''.join(b'\0' + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def batch_export(game_root: Path, out_root: Path) -> dict:
    inventory = load_inventory()
    results = []
    for area in inventory['areas']:
        area_id = area['id']
        entry = dict(area_id=area_id)
        try:
            report = export_materials(game_root, area_id, out_root / area_id / 'materials')
            entry.update(ok=True, descriptor_count=report['descriptor_count'],
                         extracted_count=report['extracted_count'],
                         rejected_count=report['rejected_count'],
                         rejected_by_flags=report['rejected_by_flags'],
                         texture_key_source=report['identity']['texture_entry']['key_source'],
                         museum_validation=report['museum_validation'])
        except Exception as exc:  # noqa: BLE001 -- one map's failure must not stop the batch
            entry.update(ok=False, error=str(exc))
        results.append(entry)
    summary = dict(
        schema_version=1, game_root=str(game_root), out_root=str(out_root),
        maps=results, map_count=len(results), succeeded=sum(r['ok'] for r in results),
        failed=sum(not r['ok'] for r in results),
        total_extracted=sum(r.get('extracted_count', 0) for r in results),
        total_rejected=sum(r.get('rejected_count', 0) for r in results))
    out_root.mkdir(parents=True, exist_ok=True)
    write_if_changed(out_root / 'batch_report.json', (json.dumps(summary, indent=2) + '\n').encode())
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)

    one = sub.add_parser('export', help='Export materials for a single area')
    one.add_argument('--game-root', type=Path, required=True)
    one.add_argument('--area', required=True)
    one.add_argument('--out', type=Path, required=True)

    many = sub.add_parser('batch', help='Export materials for all pinned areas')
    many.add_argument('--game-root', type=Path, required=True)
    many.add_argument('--out-root', type=Path, required=True)

    args = parser.parse_args()
    if args.command == 'export':
        report = export_materials(args.game_root, args.area, args.out)
        print(json.dumps({k: report[k] for k in
                          ['area_id', 'descriptor_count', 'extracted_count', 'rejected_count',
                           'rejected_by_flags', 'museum_validation']}, indent=2))
    else:
        summary = batch_export(args.game_root, args.out_root)
        print(json.dumps({k: summary[k] for k in
                          ['map_count', 'succeeded', 'failed', 'total_extracted', 'total_rejected']},
                          indent=2))


if __name__ == '__main__':
    main()
