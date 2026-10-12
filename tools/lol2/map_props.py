#!/usr/bin/env python3
"""Shared whole-game LoL2 static prop pipeline: export decorative prop placements
for any of the 15 pinned level MIXes in docs/game-geometry-profiles.json.

Entry classification reuses tools/lol2/map_materials.identify_entries() (not
edited here) so the geometry/texture/metadata split stays a single source of
truth across the materials and props pipelines. The texture entry is decoded
with the same bounded liblzo2 helper; props read sprite descriptors (flags
0x28E/0x828E ordinary, 0x2C6 packed-variant sequence) directly out of that
blob, since map_materials.py's decoded `materials` only cover the
0xA9/0xE1/0x8B/0x80A9/0x8F/0x808F surface-material families -- the prop
sprite families are this module's job. Row bytes, the index-1 mask and the
shade-row-64 destination remap come from tools/lol2/map_sprite_rows.py.

The metadata entry (structurally identified: first word 18, second word 516)
holds a bounded template/state/frame table, ported from the layout in
tools/export_museum_props.py: template count/offset at bytes 8/0x40, 55-byte
template records (selector count = byte46+byte47, flags = byte50), 16-byte
state records (byte13 signed frame count, byte15 a state-height byte)
immediately after, then 12-byte frame records (descriptor id, trim bytes).

Template flags (byte50) is a bitmask, not an enum -- see
`/home/bob/lol2_re_publish_20260911/tools/draracle/verify_prop_region_height.py`
and docs/textured-cave-preview.md's "flag1"/"region-height flag2" sections:

  * bit0 (1): F1C58 resource routing and F1DD4 height selection both ignore
    this bit; flags0 and flags1 templates draw via the exact same ordinary
    resource+height path (docs/textured-cave-preview.md, "Hanging vegetation
    expanded"). No behavioural difference is rendered for bit0.
  * bit1 (2): F1DD2..F1E12 (native, disassembly-replayed against 88 source +
    174 further source + 246 synthetic cases, 0 mismatches) selects the
    sprite's height byte as `min(255, ceiling - floor) & 0xFF` of the
    placement's own assigned region when one is bound, instead of the state
    table's own height byte -- everything else (left/right/bottom, the
    descriptor/resource itself) is unaffected. This is implemented below as
    `region_height()`, applied per-placement (not per-template, since it
    depends on each placement's own region).
  * bits 2/3 (4/8): F1C58 resource routing masks these bits to choose an
    *alternate* resource -- which resource that is has no proof anywhere in
    this codebase, so any template with these bits set is deferred wholesale
    (visual would be a guess). In the 15 pinned archives byte50 is only ever
    observed as 0/1/2/3, so this path is a defensive guard, not exercised.

Every one of a template's selectors (not just selector0) is decoded and may
be rendered: a placement's own byte35 selects which selector's initial state
it starts in (bounds-checked against that template's selector count; every
placement whose template has exactly one selector was independently verified
to have byte35==0 across all 15 archives, but this is no longer assumed for
multi-selector templates -- their *initial* visual state is in scope even
though which trigger/condition later switches selectors is not).

A frame's descriptor may decode as an ordinary sprite (0x28E, or the
structurally-identical 0x828E -- same 6H11I record and row format, just a
different literal flags word, validated by successful decode rather than
assumed), a packed-variant sequence (0x2C6, already proven for the museum's
brazier sequences, or 0x82C6 -- the same row encoding with that flags word
passed through), or fail as unsupported (deferred with its literal flags
value). Sequence variant counts are accepted only for 1..256, and the
decoded frames must consume exactly the descriptor's source span (payload
start through the mip boundary). That bound covers the Hive Caves sequence
of 73 frames (L5_HC descriptor 81) and the Bane sequence of 70 frames
(L20_BB descriptor 52). Longer sequences stay deferred.

Descriptor flags 0 is, in every pinned archive, a single all-zero record
(index 0, no payload). The draw path at F1BD6 sign-extends the frame's
descriptor word and skips the blit when it is zero, so these placements
have no initial image. They are recorded in `nonvisual_props` (source ids,
reason, raw placement and descriptor bytes), not in `issues`.

Flags 0x1246 is the block/codebook family. Prop frames use the same
descriptor index as every other family (F1C58 resource slot). Pixels come
from extract_block_sprite_frames.decode_blocks plus that descriptor's
codebook, not from the 0x28E row grammar. Index 0 is transparent. Index 1
is a palette colour for this family, so the shadow mask is empty rather
than an index-1 cutout. One descriptor is one frame; variant-count is not
treated as a row-sequence length.

A negative state frame-count (signed byte 13) is consumed by the state
loader at F2C37 as exactly one 12-byte frame, and F2C54 returns frame
index 0 for every signed count <= 0 (same initial image as count 1, no
state-clock advance). When that one descriptor is a texture sprite it is
rendered as the initial visual and later state frames are named as not
claimed. A negative count does not redirect unless the frame descriptor is
an inactive movie: kind 0x342 and original 56-byte record byte +8 equal to
255 (the runtime 12-byte descriptor sentinel read on the F1CC1 path).
Descriptor 0 is skipped before that branch and stays the existing nonvisual
decode. F1CCD then takes signed state byte 13 (`mov edx,[ebx+0xA]; sar edx,24`),
and the next state is `selector - signed_byte13` (state pointer plus
`(-signed_byte13)<<4`, back to F1B81). `resolve_templates` still returns the
same 6-tuple; `export_props` applies that redirect in a postpass. The
placement keeps its source selector. The drawn prop uses the fallback
state's geometry, and `video_references` keeps the original movie row.
A loop or an index outside the template is an explicit error. The movie-active
bypass (object flag 0x80000) is clear at the ordinary constructor, so this is
the initial still, not playback. Nested 0x2C6 sequences
inside a multi-frame state keep each packed sequence intact: the placement
shows the initial frame's own sequence, and `state_frames` retains the
rest. Those sequences are not concatenated into one timing strip.

Frame-record byte 2 bits 0x40 and 0x80 stay on `frame_hex` / `frame_flags`
for the root renderer (column flip / row flip). Images are not pre-flipped.
Animation material keys are not reused by a static placement of the same
first image, so `animated` stays false for that static placement.

Row control word bit 0x8000 marks index 1. Colour output keeps index 0 and
index 1 at alpha 0. A separate grayscale mask (0 or 255) records index 1.
No black-with-alpha shadow is invented. The native destination remap for
index 1 is shade row 64 (sections[4] + 0x4000, 256 bytes), stored as
per-area metadata rather than composited.

Placement region word at byte 10 equal to 65535 is stored by constructor
0xAE990 as a null region pointer: 0xAEA36 compares that word with -1 and
skips 0xAF0E0. Spawn then calls vtable 0xA848+0x18, which is 0xAF260. With
object byte 0x15 bit 0x10 clear it calls 0xAF0E0, and 0xAF0E0 calls 0xF40AC
with the fixed X/Y from object+0/+4 (placement signed shorts at bytes 0 and
2, shifted 16). A null hint makes 0xF40AC call 0xF3FE4(x, y, -1). That walks
every region record (stride 0x2C, count at runtime [0x22D2C]) and calls
0xF3D20. 0xF3D20 is an AABB test plus four same-side edge tests on the
region's four vertex words at +0xC. A failed test continues. When every
region fails, 0xF40A1 returns 0 and 0xAF18A does not store a pointer.
0xF1DD2 then uses the state height byte. The source region word stays on
placement_hex. A null lookup is not an active/inactive claim. A bound region
still uses ceiling-floor.

Every placement is accounted for: rendered into `props`, recorded in
`nonvisual_props` when the initial descriptor is the empty all-zero record,
or listed in `issues` with an explicit reason. Summary `accounted` is
rendered + nonvisual + issues and matches the source placement count.
Nothing here infers activation, collision, AI or quest behaviour; this is
a static/animated decoration geometry export only.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import map_materials as mm  # noqa: E402 -- reused read-only; not edited by this module
import map_sprite_rows as sprite_rows  # noqa: E402

from lol2_creature_sprite_format import decode_blocks, lcw  # noqa: E402

from PIL import Image  # noqa: E402

DEFAULT_GAME_ROOT = Path('/home/bob/lol2_out/museum_capture_20260913/game')
DEFAULT_OUT_ROOT = Path('/home/bob/lol2_out/all_maps_20260922')

ORDINARY_FLAGS = (0x28E, 0x828E)
SEQUENCE_FLAGS = (0x2C6, 0x82C6)
BLOCK_FLAGS = (0x1246,)
EXTERNAL_NAME_FLAGS = 0x342
MAX_SEQUENCE_VARIANTS = 256

require = mm.require
sha256_hex = mm.sha256_hex


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from('<I', data, offset)[0]


def s16(value: int) -> int:
    return value - 0x10000 if value & 0x8000 else value


def region_height(floor: int, ceiling: int) -> int:
    """Port of verify_prop_region_height.selected_height's region branch."""
    return min(255, ceiling - floor) & 0xff


def write_png_rgba(path: Path, width: int, height: int, rgba: bytes) -> None:
    require(len(rgba) == width * height * 4, 'invalid RGBA image extent')

    def chunk(kind: bytes, content: bytes) -> bytes:
        return (struct.pack('>I', len(content)) + kind + content
                + struct.pack('>I', zlib.crc32(kind + content)))

    rows = b''.join(b'\0' + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    data = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))
    path.write_bytes(data)


def load_templates(meta: bytes) -> dict:
    """Parse the bounded template/state/frame table (see module docstring)."""
    require(len(meta) >= 0x44 and u32(meta, 0) == 18 and u32(meta, 4) == 516,
            'metadata entry does not match the proven template-table header')
    off, count = u32(meta, 8), u32(meta, 0x40)
    require(off + count * 55 + 4 <= len(meta), 'template table exceeds metadata entry')
    state_offset = off + count * 55 + 4
    state_count = u32(meta, state_offset - 4)
    require(state_offset + state_count * 16 + 4 <= len(meta), 'state table exceeds metadata entry')
    frame_offset = state_offset + state_count * 16 + 4
    frame_count = u32(meta, frame_offset - 4)
    require(frame_offset + frame_count * 12 <= len(meta), 'frame table exceeds metadata entry')

    templates = []
    state, frame = 0, 0
    for t in range(count):
        d = meta[off + t * 55:off + (t + 1) * 55]
        n = d[46] + d[47]
        selectors = []
        for selector in range(n):
            require(state < state_count, 'state index outside table')
            s = meta[state_offset + state * 16:state_offset + (state + 1) * 16]
            c = struct.unpack_from('<b', s, 13)[0]
            nf = 1 if c < 0 else c
            require(frame + nf <= frame_count, 'frame range outside table')
            frames = []
            for fi in range(nf):
                f = meta[frame_offset + (frame + fi) * 12:frame_offset + (frame + fi + 1) * 12]
                frames.append(dict(
                    descriptor=struct.unpack_from('<h', f)[0],
                    left=-s[14] / 2 + f[5], right=s[14] / 2 - f[7],
                    bottom=f[8], top_trim=f[6],
                    frame_flags=f[2], frame_hex=f.hex(),
                    frame_offset=frame_offset + (frame + fi) * 12))
            selectors.append(dict(selector=selector, frame_count=c, state_height=s[15],
                                   state_hex=s.hex(), state_offset=state_offset + state * 16,
                                   frames=frames))
            state += 1
            frame += nf
        templates.append(dict(index=t, selector_count=n, flags=d[50],
                               template_hex=d.hex(), selectors=selectors))
    require(state == state_count and frame == frame_count, 'unaccounted states/frames')
    return dict(templates=templates, state_count=state_count, frame_count=frame_count)


def _rel(out: Path, path: Path) -> str:
    return str(path.relative_to(out))


def _write_exact_sprite(out: Path, sprites_dir: Path, colour_name: str,
                        sprite: dict, rgb: bytes, rgba: bytes | None = None) -> dict:
    """Colour PNG keeps `colour_name`. Index and shadow are sibling grayscale masks.

    Shadow is mode L, 255 only where the index is 1. It is not a black RGBA image.
    """
    sprites_dir.mkdir(parents=True, exist_ok=True)
    width, height = sprite['width'], sprite['height']
    colour_path = sprites_dir / colour_name
    stem = colour_name[:-4] if colour_name.endswith('.png') else colour_name
    index_path = sprites_dir / f'{stem}_index.png'
    shadow_path = sprites_dir / f'{stem}_shadow.png'
    colour = sprite_rows.colour_rgba(sprite, rgb) if rgba is None else rgba
    write_png_rgba(colour_path, width, height, colour)
    Image.frombytes('L', (width, height), sprite['indices']).save(index_path)
    Image.frombytes('L', (width, height), sprite['shadow_mask']).save(shadow_path)
    return dict(image=_rel(out, colour_path), index=_rel(out, index_path),
                shadow=_rel(out, shadow_path), omitted_index1_pixels=sprite['count'])


def _block_colour_rgba(indices: bytes, rgb: bytes) -> bytes:
    """Block-family colour. Index 0 is transparent. Every other index, including 1, is opaque.

    This is not the 0x28E row rule that treats index 1 as a destination-remap shadow.
    """
    out = bytearray(len(indices) * 4)
    for i, index in enumerate(indices):
        colour = rgb[index * 3:index * 3 + 3]
        alpha = 0 if index == 0 else 255
        out[i * 4:i * 4 + 4] = bytes(colour) + bytes((alpha,))
    return bytes(out)


def _load_codebook(blob: bytes, sec: tuple, codebook_index: int, codebooks: dict) -> bytes:
    if codebook_index in codebooks:
        return codebooks[codebook_index]
    require(0 <= codebook_index < 17, 'unsupported codebook table index')
    require(len(sec) > 9, 'texture container has no codebook section')
    off, allocation, packed = struct.unpack_from('<3I', blob, sec[9] + codebook_index * 12)
    require(sec[8] <= off and off + allocation <= sec[9] and 0 < packed <= allocation,
            'codebook storage extent')
    book = lcw(blob[off:off + packed])
    codebooks[codebook_index] = book
    return book


def build_image(k: int, blob: bytes, sec: tuple, rgb: bytes,
                 sprites_dir: Path, out: Path, cache: dict, codebooks: dict | None = None) -> dict:
    """Decode and cache one texture descriptor as a prop sprite (or sequence)."""
    if k in cache:
        return cache[k]
    descriptor_count = (sec[3] - sec[2]) // 56
    require(0 <= k < descriptor_count, 'descriptor index outside table')
    record = blob[sec[2] + k * 56:sec[2] + (k + 1) * 56]
    v = struct.unpack_from('<6H11I', record)
    kind = v[3]
    key = f'prop_{k}'
    if kind == 0:
        require(all(word == 0 for word in v),
                f'descriptor {k} flags 0 but the record is not all-zero')
        raise ValueError(
            f'nonvisual descriptor {k}: all-zero resource record (flags 0, '
            'no payload); intentionally empty slot, not a sprite decode')
    if kind in ORDINARY_FLAGS:
        require(v[4] == 1, f'unsupported ordinary descriptor variant count {v[4]}')
        start, size = sec[3] + v[7], v[12]
        require(start + size <= len(blob), 'sprite payload exceeds blob')
        payload = blob[start:start + size]
        sprite = sprite_rows.decode_sprite(payload, expected_flags=kind)
        require((sprite['width'], sprite['height']) == (v[1], v[2]),
                'sprite dimensions differ from descriptor')
        written = _write_exact_sprite(out, sprites_dir, f'prop_{k}.png', sprite, rgb)
        image = dict(key=key, kind='ordinary', width=sprite['width'], height=sprite['height'],
                     descriptor_flags=kind, payload_sha256=sha256_hex(payload), **written)
    elif kind in SEQUENCE_FLAGS:
        require(1 <= v[4] <= MAX_SEQUENCE_VARIANTS,
                f'sequence variant count {v[4]} out of range')
        pos = sec[3] + v[7]
        span_end = sec[3] + v[8]
        require(pos <= span_end <= len(blob), 'sequence source span outside blob')
        frames = []
        for variant in range(v[4]):
            require(pos + 8 <= span_end, 'sequence header exceeds source span')
            size = 8 + struct.unpack_from('<H', blob, pos + 6)[0]
            require(pos + size <= span_end, 'sequence frame exceeds source span')
            if variant == 0:
                require(size == v[12], 'first sequence frame size differs from descriptor')
            payload = blob[pos:pos + size]
            sprite = sprite_rows.decode_sprite(payload, expected_flags=kind)
            require((sprite['width'], sprite['height']) == (v[1], v[2]),
                    'sequence frame dimensions differ from descriptor')
            written = _write_exact_sprite(
                out, sprites_dir, f'prop_{k}_frame_{variant}.png', sprite, rgb)
            frames.append(dict(payload_sha256=sha256_hex(payload), **written))
            pos += size
        require(pos == span_end, 'sequence/mip boundary mismatch')
        image = dict(key=key, kind='sequence', width=v[1], height=v[2], descriptor_flags=kind,
                     image=frames[0]['image'], index=frames[0]['index'], shadow=frames[0]['shadow'],
                     frames=[fr['image'] for fr in frames],
                     index_frames=[fr['index'] for fr in frames],
                     shadow_frames=[fr['shadow'] for fr in frames],
                     frame_records=frames)
    elif kind in BLOCK_FLAGS:
        # Same descriptor slot as 0x28E/0x2C6. Variant count is not a row-sequence length.
        start, size = sec[3] + v[7], v[12]
        require(start + size <= len(blob), 'block payload exceeds blob')
        payload = blob[start:start + size]
        require(len(payload) >= 12, 'block payload shorter than codebook index')
        codebook_index = struct.unpack_from('<I', payload, 8)[0]
        book = _load_codebook(blob, sec, codebook_index, {} if codebooks is None else codebooks)
        width, height, pixels, _used, _tail = decode_blocks(payload, book)
        require((width, height) == (v[1], v[2]), 'block dimensions differ from descriptor')
        sprite = dict(width=width, height=height, indices=pixels,
                      shadow_mask=bytes(width * height), count=0)
        written = _write_exact_sprite(out, sprites_dir, f'prop_{k}.png', sprite, rgb,
                                       rgba=_block_colour_rgba(pixels, rgb))
        image = dict(key=key, kind='block', width=width, height=height, descriptor_flags=kind,
                     codebook=codebook_index, payload_sha256=sha256_hex(payload),
                     index1_policy='palette colour; block family has no row-grammar index-1 shadow',
                     **written)
    elif kind == EXTERNAL_NAME_FLAGS:
        start, size = sec[3] + v[7], v[12]
        require(start + size <= len(blob), 'named-resource payload exceeds blob')
        payload = blob[start:start + size]
        name = payload[8:].split(b'\0', 1)[0]
        try:
            filename = name.decode('ascii')
        except UnicodeDecodeError:
            filename = name.hex()
        raise ValueError(
            f'external 0x342 resource {filename!r} (raw {payload.hex()}); '
            'not a texture-family sprite')
    else:
        raise ValueError(f'unsupported descriptor kind 0x{kind:x}')
    cache[k] = image
    return image


def _suffixed_key(base: str, template: int, selector: int) -> str:
    return f'{base}__t{template}s{selector}'


def animation_key(base: str, colour_frames: list, animations: dict, template: int, selector: int,
                  static_keys: set | None = None) -> str:
    """Keep animation keys from colliding with each other or with a static material.

    Identical frame lists reuse `base` (`prop_<descriptor>`). A different list, or a
    `base` already used as a static (non-animated) material, gets
    `prop_<descriptor>__t<template>s<selector>`. Sharing `base` would make
    `animated = material in animations` true for the static placement.
    """
    if static_keys and base in static_keys:
        return _suffixed_key(base, template, selector)
    previous = animations.get(base)
    if previous is not None and previous['frames'] != colour_frames:
        return _suffixed_key(base, template, selector)
    return base


def static_material_key(base: str, animations: dict, template: int, selector: int) -> str:
    """Do not reuse an animation key for a placement that shows only the still image."""
    if base in animations:
        return _suffixed_key(base, template, selector)
    return base


def _sequence_animation(image: dict) -> dict:
    return dict(frames=image['frames'], index_frames=image['index_frames'],
                shadow_frames=image['shadow_frames'], fps=10,
                timing='provisional; native sequence rate/phase unverified')


def _state_frame_record(image: dict, fr: dict) -> dict:
    record = dict(descriptor=fr['descriptor'], kind=image['kind'],
                  frame_hex=fr['frame_hex'], frame_flags=fr['frame_flags'],
                  frame_offset=fr['frame_offset'], left=fr['left'], right=fr['right'],
                  bottom=fr['bottom'], top_trim=fr['top_trim'],
                  image=image['image'], index=image['index'], shadow=image['shadow'])
    if image['kind'] == 'sequence':
        record.update(frames=image['frames'], index_frames=image['index_frames'],
                      shadow_frames=image['shadow_frames'])
    return record


def _bind_still(image: dict, animations: dict, materials: dict, static_keys: set,
                template: int, selector: int) -> str:
    key = static_material_key(image['key'], animations, template, selector)
    materials[key] = image['image']
    if key == image['key']:
        static_keys.add(key)
    return key


def _visual_from_frame(image: dict, fr: dict, sel: dict, needs_region_height: bool, material: str) -> dict:
    return dict(width=image['width'], height=image['height'],
                left=fr['left'], right=fr['right'], bottom=fr['bottom'],
                top_trim=fr['top_trim'], state_height=sel['state_height'],
                needs_region_height=needs_region_height, material=material,
                state_hex=sel['state_hex'], state_offset=sel['state_offset'],
                frame_hex=fr['frame_hex'], frame_flags=fr['frame_flags'],
                frame_offset=fr['frame_offset'])


def inactive_movie_sentinel(frame_count: int, descriptor: int, record: bytes) -> bool:
    """Supported negative-count case of the F1CC1 inactive-movie redirect.

    Ordinary negative counts (texture descriptors) are not sentinels.
    Descriptor 0 is skipped before the sentinel branch. Byte +8 of the
    original 56-byte record is the 255 variant/count sentinel.
    Positive-count states need initial phase selection and remain deferred here.
    """
    if frame_count >= 0 or descriptor == 0 or len(record) < 9:
        return False
    kind = struct.unpack_from('<H', record, 6)[0]
    return kind == EXTERNAL_NAME_FLAGS and record[8] == 255


def follow_movie_fallback(selector_count: int, start: int, sentinel_counts: dict, kinds: dict) -> dict:
    """Walk selector - signed_state_byte13 until a non-movie state.

    `sentinel_counts` maps a movie selector to its signed byte 13.
    `kinds` maps any other selector to 'visual', 'nonvisual', or an error string.
    Cycles and indexes outside the template are explicit failures.
    """
    chain = []
    current = start
    while True:
        if current < 0 or current >= selector_count:
            return dict(ok=False, chain=chain,
                        reason=f'inactive movie fallback selector {current} outside '
                               f'template selector count {selector_count}')
        if current in chain:
            return dict(ok=False, chain=chain,
                        reason=f'inactive movie fallback cycle through selectors {chain + [current]}')
        chain.append(current)
        if current in sentinel_counts:
            current = current - sentinel_counts[current]
            continue
        kind = kinds.get(current)
        if kind in ('visual', 'nonvisual'):
            return dict(ok=True, kind=kind, displayed=current, chain=chain,
                        reason=None)
        detail = kind or 'no resolved state'
        return dict(ok=False, chain=chain,
                    reason=f'inactive movie fallback selector {current} did not resolve: {detail}')


def _descriptor_record(blob: bytes, sec: tuple, descriptor: int) -> bytes | None:
    descriptor_count = (sec[3] - sec[2]) // 56
    if not isinstance(descriptor, int) or descriptor < 0 or descriptor >= descriptor_count:
        return None
    return blob[sec[2] + descriptor * 56:sec[2] + (descriptor + 1) * 56]


def index_movie_fallbacks(templates: list, visuals: dict, selector_issues: dict,
                           selector_extra: dict, blob: bytes, sec: tuple) -> dict:
    """Postpass over resolve_templates. Does not change that 6-tuple."""
    fallbacks = {}
    by_index = {template['index']: template for template in templates}
    for key, reason in selector_issues.items():
        template_index, selector = key
        extra = selector_extra.get(key, {})
        frame_count = extra.get('source_frame_count')
        descriptor = extra.get('descriptor')
        if not isinstance(frame_count, int):
            continue
        record = _descriptor_record(blob, sec, descriptor)
        if record is None or not inactive_movie_sentinel(frame_count, descriptor, record):
            continue
        template = by_index[template_index]
        sentinel_counts = {}
        kinds = {}
        for sel in template['selectors']:
            sel_key = (template_index, sel['selector'])
            sel_extra = selector_extra.get(sel_key, {})
            sel_count = sel['frame_count']
            sel_descriptor = sel['frames'][0]['descriptor'] if sel['frames'] else None
            sel_record = _descriptor_record(blob, sec, sel_descriptor)
            if (sel_key in selector_issues and sel_record is not None
                    and inactive_movie_sentinel(sel_count, sel_descriptor, sel_record)):
                sentinel_counts[sel['selector']] = sel_count
            elif sel_key in visuals:
                kinds[sel['selector']] = 'visual'
            elif selector_issues.get(sel_key, '').startswith('nonvisual descriptor'):
                kinds[sel['selector']] = 'nonvisual'
            elif sel_key in selector_issues:
                kinds[sel['selector']] = selector_issues[sel_key]
        fallbacks[key] = follow_movie_fallback(
            template['selector_count'], selector, sentinel_counts, kinds)
        fallbacks[key]['source_reason'] = reason
    return fallbacks


def resolve_templates(templates: list, blob: bytes, sec: tuple, rgb: bytes,
                       sprites_dir: Path, out: Path, images_cache: dict) -> tuple:
    """Classify every (template, selector) as a supported visual, or defer it.

    Returns (visuals, selector_issues, selector_extra, deferred_templates, materials, animations).
    `visuals` is keyed by (template_index, selector_index); its `top` is left
    unresolved (None) when the template needs per-placement region-height.
    """
    visuals, selector_issues, selector_extra, deferred_templates = {}, {}, {}, []
    materials, animations = {}, {}
    static_keys: set = set()
    codebooks: dict = {}
    descriptor_count = (sec[3] - sec[2]) // 56

    def decode(descriptor: int) -> dict:
        return build_image(descriptor, blob, sec, rgb, sprites_dir, out, images_cache, codebooks)

    for template in templates:
        t, flags = template['index'], template['flags']
        if flags & ~3:
            deferred_templates.append(dict(
                template=t, selector_count=template['selector_count'], flags=flags,
                reason=f'template flags={flags}; resource-routing bits beyond 0/1 '
                       '(F1C58 masks 4/8) not proven for props'))
            continue
        needs_region_height = bool(flags & 2)
        for sel in template['selectors']:
            key = (t, sel['selector'])
            c, frames = sel['frame_count'], sel['frames']
            try:
                if c < 0:
                    # F2C37 consumes one frame; F2C54 returns index 0. No further state frames.
                    fr = frames[0]
                    image = decode(fr['descriptor'])
                    if image['kind'] == 'sequence':
                        animations[image['key']] = _sequence_animation(image)
                        material = image['key']
                        materials[material] = image['image']
                    else:
                        material = _bind_still(image, animations, materials, static_keys, t, sel['selector'])
                    visual = _visual_from_frame(image, fr, sel, needs_region_height, material)
                    visual['later_state_frames'] = (
                        'not claimed; signed count consumes exactly one frame record '
                        'and F2C54 returns index 0')
                    visual['source_frame_count'] = c
                    visuals[key] = visual
                    continue
                if len(frames) == 1:
                    fr = frames[0]
                    image = decode(fr['descriptor'])
                    if image['kind'] == 'sequence':
                        animations[image['key']] = _sequence_animation(image)
                        materials[image['key']] = image['image']
                        material = image['key']
                    else:
                        material = _bind_still(image, animations, materials, static_keys, t, sel['selector'])
                    visuals[key] = _visual_from_frame(image, fr, sel, needs_region_height, material)
                else:
                    decoded = [(decode(fr['descriptor']), fr) for fr in frames]
                    if any(image['kind'] == 'sequence' for image, _fr in decoded):
                        # Each packed sequence stays its own frame list. Initial visual is frame 0 only.
                        first_image, first_fr = decoded[0]
                        if first_image['kind'] == 'sequence':
                            animations[first_image['key']] = _sequence_animation(first_image)
                            materials[first_image['key']] = first_image['image']
                            material = first_image['key']
                        else:
                            material = _bind_still(
                                first_image, animations, materials, static_keys, t, sel['selector'])
                        visual = _visual_from_frame(
                            first_image, first_fr, sel, needs_region_height, material)
                        visual['state_frames'] = [_state_frame_record(image, fr) for image, fr in decoded]
                        visual['later_state_frames'] = (
                            'source state frames retained with each packed sequence; '
                            'not flattened into one timing strip')
                        visuals[key] = visual
                    else:
                        frame_images = []
                        for image, fr in decoded:
                            if image['kind'] not in ('ordinary', 'block'):
                                raise ValueError(
                                    f"animation frame descriptor {fr['descriptor']} kind {image['kind']} "
                                    'has no proven state-frame timing')
                            frame_images.append((image, fr))
                        first_image, first_fr = frame_images[0]
                        colour_frames = [im['image'] for im, _fr in frame_images]
                        anim_key = animation_key(
                            first_image['key'], colour_frames, animations, t, sel['selector'], static_keys)
                        materials[anim_key] = first_image['image']
                        animations[anim_key] = dict(
                            frames=colour_frames,
                            index_frames=[im['index'] for im, _fr in frame_images],
                            shadow_frames=[im['shadow'] for im, _fr in frame_images],
                            fps=10, timing='provisional; native per-frame state timing unverified')
                        visual = _visual_from_frame(
                            first_image, first_fr, sel, needs_region_height, anim_key)
                        visual['frame_hexes'] = [fr['frame_hex'] for _im, fr in frame_images]
                        visual['frame_flags_list'] = [fr['frame_flags'] for _im, fr in frame_images]
                        visuals[key] = visual
            except ValueError as exc:
                reason = str(exc)
                selector_issues[key] = reason
                extra = {}
                if frames:
                    fr = frames[0]
                    extra = dict(descriptor=fr['descriptor'], frame_hex=fr['frame_hex'],
                                 frame_flags=fr['frame_flags'], source_frame_count=c)
                    if reason.startswith('nonvisual descriptor') and isinstance(fr['descriptor'], int):
                        desc = fr['descriptor']
                        if 0 <= desc < descriptor_count:
                            extra['descriptor_hex'] = blob[sec[2] + desc * 56:sec[2] + (desc + 1) * 56].hex()
                    if c < 0:
                        extra['later_state_frames'] = (
                            'not claimed; signed count consumes exactly one frame record '
                            'and F2C54 returns index 0')
                if extra:
                    selector_extra[key] = extra
    return visuals, selector_issues, selector_extra, deferred_templates, materials, animations


def export_props(game_root: Path, area_id: str, out: Path, material_root: Path | None = None) -> dict:
    """Export static/animated decorative prop placements for one pinned level MIX into `out`.

    `material_root`, if given and containing a `texture.bin` from
    tools/lol2/map_materials.py's export for the same area, is used only as a
    byte-identity cross-check against this module's own independent LZO
    decode -- never as a silent substitute, since props decode descriptor
    families (0x28E/0x828E/0x2C6) that map_materials.py does not.

    Returns the same report dict written to `out/props.json`.
    """
    inventory = mm.load_inventory()
    area = mm.area_by_id(inventory, area_id)
    source = area['source']

    mix_path = game_root / source['file']
    mix = mix_path.read_bytes()
    require(sha256_hex(mix) == source['sha256'], f'{area_id}: unsupported or changed archive')

    entries = mm.parse_mix(mix)
    identity = mm.identify_entries(mix, entries, source['geometry_key'])

    geo_entry = identity['geometry_entry']
    geo = mix[geo_entry['offset']:geo_entry['offset'] + geo_entry['size']]
    require(u32(geo, 0) == 18, 'unsupported geometry format marker')

    meta_entry = identity['metadata_entry']
    meta = mix[meta_entry['offset']:meta_entry['offset'] + meta_entry['size']]
    parsed = load_templates(meta)
    templates = parsed['templates']

    blob, decode_info = mm.decode_lzo_container(mix, identity['texture_entry'])
    materials_cross_check = None
    if material_root is not None:
        texture_path = material_root / 'texture.bin'
        if texture_path.is_file():
            materials_cross_check = dict(texture_bin=str(texture_path),
                                          byte_identical=texture_path.read_bytes() == blob)

    sec = mm.sections(blob)
    require(sec[3] > sec[2] > 0 and (sec[3] - sec[2]) % 56 == 0, 'descriptor table extent')
    descriptor_count = (sec[3] - sec[2]) // 56
    palette_offset = u32(blob, 4)
    require(palette_offset + 768 <= len(blob), 'palette outside blob')
    rgb = mm.rgb_palette(blob[palette_offset:palette_offset + 768], 6)
    source_sha = sha256_hex(blob)
    remap = sprite_rows.initial_remap_row(blob, source_sha)
    initial_remap = dict(
        row=sprite_rows.REMAP_ROW, length=len(remap),
        offset_rule='sections[4] + 0x4000', source_sha256=source_sha,
        remap_sha256=sha256_hex(remap), remap_hex=remap.hex())

    out.mkdir(parents=True, exist_ok=True)
    sprites_dir = out / 'sprites'
    images_cache: dict = {}
    visuals, selector_issues, selector_extra, deferred_templates, materials, animations = resolve_templates(
        templates, blob, sec, rgb, sprites_dir, out, images_cache)
    movie_fallbacks = index_movie_fallbacks(
        templates, visuals, selector_issues, selector_extra, blob, sec)
    template_deferred_reason = {d['template']: d['reason'] for d in deferred_templates}

    placement_off, placement_count = u32(geo, 0x14), u32(geo, 0x60)
    require(placement_off + placement_count * 37 <= len(geo), 'placement table exceeds geometry entry')
    region_count = u32(geo, 0x58)
    region_table_offset = u32(geo, 12)
    require(region_table_offset + region_count * 44 <= len(geo), 'region table exceeds geometry entry')

    def region_floor_ceiling(region: int) -> tuple:
        r = struct.unpack_from('<22H', geo, region_table_offset + region * 44)
        return s16(r[10]), s16(r[11])

    props, issues, nonvisual, video_references = [], [], [], []
    for i in range(placement_count):
        o = placement_off + i * 37
        d = geo[o:o + 37]
        t = struct.unpack_from('<H', d, 32)[0]
        selector = d[35]
        region_raw = struct.unpack_from('<H', d, 10)[0]
        region = None if region_raw == 65535 else region_raw
        base = dict(record=i, template=t, selector=selector, region=region,
                    placement_offset=geo_entry['offset'] + o, placement_hex=d.hex())

        if t >= len(templates):
            issues.append(dict(**base, reason='template index outside table'))
            continue
        template = templates[t]
        if t in template_deferred_reason:
            issues.append(dict(**base, reason=template_deferred_reason[t]))
            continue
        if selector >= template['selector_count']:
            issues.append(dict(**base, reason='selector index outside template selector table'))
            continue
        key = (t, selector)
        fallback = movie_fallbacks.get(key)
        if fallback is not None:
            source_sel = template['selectors'][selector]
            video_references.append(dict(
                **base, reason=selector_issues[key], **selector_extra.get(key, {}),
                state_hex=source_sel['state_hex'], state_offset=source_sel['state_offset']))
            if not fallback['ok']:
                issues.append(dict(**base, reason=fallback['reason'],
                                    fallback_chain=fallback['chain'],
                                    **selector_extra.get(key, {}),
                                    state_hex=source_sel['state_hex']))
                continue
            shown_key = (t, fallback['displayed'])
            provenance = dict(source_selector=selector, displayed_selector=fallback['displayed'],
                              fallback_chain=fallback['chain'])
            if fallback['kind'] == 'nonvisual':
                shown = template['selectors'][fallback['displayed']]
                nonvisual.append(dict(
                    **base, reason=selector_issues[shown_key], **selector_extra.get(shown_key, {}),
                    **provenance, state_hex=shown['state_hex'], state_offset=shown['state_offset']))
                continue
            visual = visuals[shown_key]
        elif key in selector_issues:
            entry = dict(**base, reason=selector_issues[key], **selector_extra.get(key, {}))
            if selector_issues[key].startswith('nonvisual descriptor'):
                nonvisual.append(entry)
            else:
                issues.append(entry)
            continue
        else:
            visual = visuals[key]
            provenance = None
        if visual['right'] <= visual['left']:
            issues.append(dict(**base, reason='degenerate sprite bounds'))
            continue

        if visual['needs_region_height'] and region is None and (area_id, i) not in {
                ('L5_HC', 615), ('L5_HC', 685), ('L5_HC', 767)}:
            # Source archive identity is pinned above. These three misses are
            # independently replayed by verify_map_null_prop_regions.py. A new
            # unbound placement may acquire a region during its constructor.
            issues.append(dict(**base, material=visual['material'],
                reason='unbound region requires native constructor lookup proof'))
            continue
        if visual['needs_region_height'] and region is not None:
            require(region < region_count, f'placement {i}: region outside map')
            floor, ceiling = region_floor_ceiling(region)
            height_byte = region_height(floor, ceiling)
        else:
            # Bound bit1 uses ceiling-floor. Word 65535 leaves the pointer null
            # after 0xF40AC finds no containing region, so 0xF1E07 stores state+0x0F.
            height_byte = visual['state_height']
        top = height_byte - visual['top_trim']

        if top <= visual['bottom']:
            issues.append(dict(**base, reason='degenerate sprite bounds'))
            continue

        x, y, z = (struct.unpack_from('<h', d, field)[0] for field in (0, 2, 6))
        prop = dict(record=i, template=t, selector=selector, position=[x, z, -y], region=region,
                    material=visual['material'], width=visual['width'], height=visual['height'],
                    left=visual['left'], right=visual['right'], bottom=visual['bottom'], top=top,
                    animated=visual['material'] in animations,
                    state_offset=visual['state_offset'], state_hex=visual['state_hex'],
                    frame_offset=visual['frame_offset'], frame_hex=visual['frame_hex'],
                    frame_flags=visual['frame_flags'],
                    placement_offset=geo_entry['offset'] + o, placement_hex=d.hex())
        if 'frame_hexes' in visual:
            prop['frame_hexes'] = visual['frame_hexes']
        if 'frame_flags_list' in visual:
            prop['frame_flags_list'] = visual['frame_flags_list']
        if 'state_frames' in visual:
            prop['state_frames'] = visual['state_frames']
        if 'later_state_frames' in visual:
            prop['later_state_frames'] = visual['later_state_frames']
        if 'source_frame_count' in visual:
            prop['source_frame_count'] = visual['source_frame_count']
        if provenance:
            prop.update(provenance)
            prop['frame_hexes'] = visual.get('frame_hexes', [visual['frame_hex']])
        props.append(prop)

    accounted = len(props) + len(nonvisual) + len(issues)
    require(accounted == placement_count, 'placement accounting mismatch')
    summary = dict(source_placements=placement_count, rendered_placements=len(props),
                    nonvisual_placements=len(nonvisual), deferred_placements=len(issues),
                    accounted=accounted, templates=len(templates),
                    resolved_selectors=len(visuals), deferred_selectors=len(selector_issues),
                    deferred_templates=len(deferred_templates),
                    descriptors=descriptor_count, rendered_images=len(images_cache),
                    animated_materials=len(animations),
                    region_height_placements=sum(
                        1 for p in props if visuals[(p['template'], p.get('displayed_selector', p['selector']))]
                        ['needs_region_height']),
                    movie_fallback_visual=sum(1 for p in props if 'displayed_selector' in p),
                    movie_fallback_nonvisual=sum(1 for row in nonvisual if 'displayed_selector' in row),
                    video_references=len(video_references))

    report = dict(
        schema_version=2, area_id=area_id, area_name=area.get('name'), level=area.get('level'),
        source=dict(file=source['file'], sha256=source['sha256'], geometry_key=source['geometry_key']),
        identity=dict(
            geometry_entry=dict(index=geo_entry['index'], key=geo_entry['key'], size=geo_entry['size']),
            metadata_entry=dict(index=meta_entry['index'], key=meta_entry['key'], size=meta_entry['size']),
            texture_entry=dict(index=identity['texture_entry']['index'], key=identity['texture_entry']['key'],
                                size=identity['texture_entry']['size'],
                                key_source=identity['texture_key_source'])),
        decode=decode_info, materials_cross_check=materials_cross_check,
        initial_remap=initial_remap,
        sprites=[images_cache[k] for k in sorted(images_cache)],
        template_states=parsed['state_count'], template_frames=parsed['frame_count'],
        props=props, nonvisual_props=nonvisual, materials=materials, animations=animations, issues=issues,
        video_references=video_references,
        deferred_templates=deferred_templates,
        deferred_selectors=[dict(template=t, selector=sel, reason=reason)
                             for (t, sel), reason in sorted(selector_issues.items())],
        summary=summary,
        scope='Every template selector (not just selector0) is decoded; a placement renders using '
              'its own source selector byte, bounds-checked against that template\'s selector '
              'count. Template flags bit0 is a proven no-op (F1C58/F1DD4 ignore it); bit1 applies '
              'the proven native region-height formula per-placement using that placement\'s own '
              'bound region; bits2/3 (unproven alternate resource routing) still defer the whole '
              'template. Ordinary (0x28E/0x828E) and packed-variant-sequence (0x2C6/0x82C6, '
              '1..256 frames, exact source span) descriptors are rendered as RGBA colour PNGs '
              'under the existing filenames, plus grayscale index and index-1 shadow-mask PNGs. '
              'Index 1 stays transparent in colour; the mask is not a black-alpha shadow. Shade '
              'row 64 is per-area remap metadata and is not composited. All-zero flags-0 '
              'descriptors are nonvisual empty slots in nonvisual_props. 0x1246 block sprites '
              'use the shared descriptor index and decode_blocks. A negative frame count renders '
              'its one consumed frame when that descriptor is a texture sprite. Inactive 0x342 '
              'descriptors whose record byte +8 is 255 redirect to selector - signed state byte 13; '
              'the drawn state supplies geometry and video_references keeps the original movie row. '
              'Loops and out-of-range indexes stay issues. Nested sequences keep per-frame packed lists. '
              'Frame bits 0x40/0x80 stay on '
              'frame_flags for the root flip. Region word 65535 is a null pointer at draw: '
              '0xF3FE4/0xF3D20 found no containing region, so bit1 uses the state height '
              'byte. The source word remains in placement_hex and region is null. That is '
              'not an active/inactive claim. A bound region still uses ceiling-floor. '
              'Multi-selector templates whose *initial* placement-selected state fails to decode, '
              'and templates with unproven flags bits, are deferred with an explicit reason. No '
              'collision, activation, AI or quest behaviour is inferred; no combat/NPC actor '
              'placements are covered; which condition switches a multi-selector object between '
              'its states over time remains out of scope.')
    (out / 'props.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def batch_export_props(game_root: Path, out_root: Path, materials_root: Path | None = None) -> dict:
    inventory = mm.load_inventory()
    results = []
    for area in inventory['areas']:
        area_id = area['id']
        entry = dict(area_id=area_id)
        # The materials worker's actual batch run writes texture.bin/materials.json
        # directly under <out_root>/<area_id> (no nested "materials" folder); check
        # that first, falling back to the nested layout tools/lol2/map_surfaces.py
        # expects, in case a future run adopts it.
        candidates = [(materials_root or out_root) / area_id,
                      (materials_root or out_root) / area_id / 'materials']
        material_root = next((c for c in candidates if (c / 'texture.bin').is_file()), candidates[0])
        try:
            report = export_props(game_root, area_id, out_root / area_id / 'props',
                                   material_root=material_root if material_root.exists() else None)
            entry.update(ok=True, **report['summary'])
        except Exception as exc:  # noqa: BLE001 -- one map's failure must not stop the batch
            entry.update(ok=False, error=str(exc))
        results.append(entry)
    summary = dict(
        schema_version=2, game_root=str(game_root), out_root=str(out_root),
        maps=results, map_count=len(results), succeeded=sum(r['ok'] for r in results),
        failed=sum(not r['ok'] for r in results),
        total_rendered_placements=sum(r.get('rendered_placements', 0) for r in results),
        total_nonvisual_placements=sum(r.get('nonvisual_placements', 0) for r in results),
        total_deferred_placements=sum(r.get('deferred_placements', 0) for r in results),
        total_accounted=sum(r.get('accounted', 0) for r in results))
    out_root.mkdir(parents=True, exist_ok=True)
    (out_root / 'props_batch_report.json').write_text(json.dumps(summary, indent=2) + '\n')
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)

    one = sub.add_parser('export', help='Export props for a single area')
    one.add_argument('--game-root', type=Path, default=DEFAULT_GAME_ROOT)
    one.add_argument('--area', required=True)
    one.add_argument('--out', type=Path, required=True)
    one.add_argument('--material-root', type=Path, default=None)

    many = sub.add_parser('batch', help='Export props for all pinned areas')
    many.add_argument('--game-root', type=Path, default=DEFAULT_GAME_ROOT)
    many.add_argument('--out-root', type=Path, default=DEFAULT_OUT_ROOT)
    many.add_argument('--materials-root', type=Path, default=None)

    args = parser.parse_args()
    if args.command == 'export':
        report = export_props(args.game_root, args.area, args.out, material_root=args.material_root)
        print(json.dumps(report['summary'], indent=2))
    else:
        summary = batch_export_props(args.game_root, args.out_root, materials_root=args.materials_root)
        print(json.dumps({k: summary[k] for k in
                          ['map_count', 'succeeded', 'failed', 'total_rendered_placements',
                           'total_nonvisual_placements', 'total_deferred_placements',
                           'total_accounted']}, indent=2))


if __name__ == '__main__':
    main()
