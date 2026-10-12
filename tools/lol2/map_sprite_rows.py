#!/usr/bin/env python3
"""Decode 0x28E-family sprite rows, keeping index 1 as a destination-remap mask.

Proven elsewhere (not re-derived here):

* tools/draracle/extract_prop_sprite_previews.py `decode_rows(..., allow_special=True)`:
  row control bit 0x8000 is set exactly when the span contains index 1, and bit
  0x4000 exactly when it contains index 0. Spans, widths and full payload
  consumption are checked there.
* tools/draracle/verify_sprite_special_pixels.py: native first-pixel path —
  index 0 keeps the destination, index 1 remaps the destination through the
  table at object offset 0x4000, index >= 2 uses the ordinary source shade.
* tools/draracle/verify_special_pixel_table_binding.py: that initial table is
  shade-section row 64, file offset sections[4] + 0x4000, 256 bytes.
* tools/draracle/extract_special_sprite_masks.py: colour output omits index 0
  and index 1 (alpha 0); the mask is white only where the index is 1.

Index 1 is never emitted as an ordinary opaque palette colour, and no
black-with-alpha shadow image is invented.
"""
from __future__ import annotations

import hashlib
import struct
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lol2_creature_sprite_format import decode_rows  # noqa: E402
from lol2_material_format import rgb_palette, sections, initial_remap_row  # noqa: E402

# Header flags word. 0x28E is the ordinary sprite. 0x828E is the same row
# format with the high bit set on the flags word. 0x82C6 is the same for the
# packed-variant frame header (0x2C6). Callers pass the exact flags.
ALLOWED_FLAGS = (0x28E, 0x828E, 0x2C6, 0x82C6)

EVIDENCE = {
    'row_decode': 'lol2_re_publish_20260911/tools/draracle/extract_prop_sprite_previews.py:decode_rows',
    'native_pixels': 'lol2_re_publish_20260911/tools/draracle/verify_sprite_special_pixels.py',
    'initial_remap': 'lol2_re_publish_20260911/tools/draracle/verify_special_pixel_table_binding.py',
    'mask_split': 'lol2_re_publish_20260911/tools/draracle/extract_special_sprite_masks.py',
}

REMAP_ROW = 64
REMAP_BYTES = 256


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def decode_sprite(payload: bytes, expected_flags: int = 0x28E) -> dict:
    """Decode one sprite payload.

    Returns width, height, indices, shadow_mask (255 where index==1 else 0),
    count of index-1 pixels, and evidence refs. Row spans, the 0x4000/0x8000
    control hints and exact payload consumption are enforced by decode_rows.
    """
    _require(expected_flags in ALLOWED_FLAGS, f'unsupported sprite flags 0x{expected_flags:x}')
    _require(isinstance(payload, (bytes, bytearray)), 'payload must be bytes')
    width, height, indices, marked = decode_rows(
        bytes(payload), expected_flags=expected_flags, allow_special=True)
    _require(len(indices) == width * height, 'index buffer extent')
    shadow = bytes(255 if index == 1 else 0 for index in indices)
    _require(shadow.count(255) == indices.count(1), 'shadow mask lost an index-1 pixel')
    return dict(
        width=width,
        height=height,
        indices=indices,
        shadow_mask=shadow,
        count=indices.count(1),
        evidence=dict(EVIDENCE, transparent_hint_rows=marked, flags=expected_flags),
    )


def palette_rgb(blob: bytes) -> bytes:
    """6-bit DAC palette at the container's proven palette offset, as 768 RGB bytes."""
    _require(len(blob) >= 8, 'blob too small for palette offset')
    offset = struct.unpack_from('<I', blob, 4)[0]
    _require(offset + 768 <= len(blob), 'palette outside blob')
    return rgb_palette(blob[offset:offset + 768], 6)


def colour_rgba(sprite: dict, palette: bytes) -> bytes:
    """RGBA colour. Index 0 and index 1 are alpha 0. Index >= 2 is opaque palette RGB.

    Index 1 is not written as opaque colour.
    """
    _require(len(palette) >= 768, 'palette')
    indices = sprite['indices']
    out = bytearray(len(indices) * 4)
    for i, index in enumerate(indices):
        rgb = palette[index * 3:index * 3 + 3]
        alpha = 0 if index <= 1 else 255
        out[i * 4:i * 4 + 4] = bytes(rgb) + bytes((alpha,))
    return bytes(out)


def save_sprite(out_dir: Path, stem: str, sprite: dict, palette: bytes) -> dict:
    """Write colour RGBA, index grayscale and shadow-mask grayscale PNGs.

    The shadow file is the index-1 mask (0 or 255), not a black alpha shadow.
    """
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    width, height = sprite['width'], sprite['height']
    _require(len(sprite['indices']) == width * height, 'indices extent')
    _require(len(sprite['shadow_mask']) == width * height, 'shadow mask extent')
    colour_path = out_dir / f'{stem}_colour.png'
    index_path = out_dir / f'{stem}_index.png'
    shadow_path = out_dir / f'{stem}_shadow.png'
    Image.frombytes('RGBA', (width, height), colour_rgba(sprite, palette)).save(colour_path)
    Image.frombytes('L', (width, height), sprite['indices']).save(index_path)
    Image.frombytes('L', (width, height), sprite['shadow_mask']).save(shadow_path)
    return dict(colour=colour_path, index=index_path, shadow=shadow_path)



def renderer_block(sprite: dict, blob: bytes, source_sha256: str) -> dict:
    """Optional renderer inputs: indices plus the pinned initial destination remap.

    Does not composite a shadow colour. Index 1 selects `initial_remap[destination]`.
    """
    row = initial_remap_row(blob, source_sha256)
    _require(len(row) == REMAP_BYTES, 'remap row length')
    return dict(
        width=sprite['width'],
        height=sprite['height'],
        indices=sprite['indices'],
        shadow_mask=sprite['shadow_mask'],
        initial_remap=row,
        initial_remap_offset_rule='sections[4] + 0x4000',
        source_sha256=source_sha256,
        evidence=sprite['evidence'],
    )
