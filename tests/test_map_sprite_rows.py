#!/usr/bin/env python3
"""Sprite row-8000 decode against on-disk L4 and cave texture blobs."""
import hashlib
import struct
import sys
from pathlib import Path

import pytest
from PIL import Image

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'tools' / 'lol2'))
sys.path.insert(0, str(REPO / 'tools'))
import map_sprite_rows as rows  # noqa: E402
from lol2_creature_sprite_format import decode_rows  # noqa: E402
from lol2_material_format import sections  # noqa: E402

OUT = Path('/home/bob/lol2_out/all_maps_20260922')
CAVE_IDS = (193, 194, 474, 475, 476)


def _blob(area: str) -> bytes:
    for rel in ('texture.bin', 'materials/texture.bin'):
        path = OUT / area / rel
        if path.is_file():
            return path.read_bytes()
    pytest.skip(f'no texture blob for {area}')


def _descriptor(blob: bytes, index: int) -> tuple:
    sec = sections(blob)
    count = (sec[3] - sec[2]) // 56
    assert 0 <= index < count
    return struct.unpack_from('<6H11I', blob, sec[2] + index * 56), sec


def _payload(blob: bytes, index: int) -> tuple[int, bytes]:
    values, sec = _descriptor(blob, index)
    flags = values[3]
    start, size = sec[3] + values[7], values[12]
    assert start + size <= len(blob)
    return flags, blob[start:start + size]


def _row8000_descriptors(blob: bytes) -> list[int]:
    sec = sections(blob)
    count = (sec[3] - sec[2]) // 56
    found = []
    for index in range(count):
        values = struct.unpack_from('<6H11I', blob, sec[2] + index * 56)
        if values[3] not in rows.ALLOWED_FLAGS or values[4] != 1:
            continue
        start, size = sec[3] + values[7], values[12]
        if start + size > len(blob) or size < 8:
            continue
        data = blob[start:start + size]
        pos, height = 8, values[2]
        special = False
        ok = True
        for _y in range(height):
            if pos + 4 > len(data):
                ok = False
                break
            control, n = struct.unpack_from('<HH', data, pos)
            pos += 4
            if pos + n > len(data):
                ok = False
                break
            if control & 0x8000:
                special = True
            pos += n
        if ok and special and pos == len(data):
            found.append(index)
    return found


def test_l4_row8000_issue_descriptors_match_decode_rows():
    blob = _blob('L4_HJ')
    specials = _row8000_descriptors(blob)
    assert specials, 'L4 texture has no row-0x8000 sprite descriptors'
    for index in specials:
        flags, payload = _payload(blob, index)
        sprite = rows.decode_sprite(payload, expected_flags=flags)
        width, height, indices, _marked = decode_rows(payload, expected_flags=flags, allow_special=True)
        assert (sprite['width'], sprite['height']) == (width, height)
        assert sprite['indices'] == indices
        assert sprite['count'] == indices.count(1) > 0
        assert sprite['shadow_mask'] == bytes(255 if i == 1 else 0 for i in indices)
        # Hint bit really tracks index 1: stripping allow_special must reject.
        with pytest.raises(ValueError):
            decode_rows(payload, expected_flags=flags, allow_special=False)


def test_cave_special_sprites_193_194_474_475_476(tmp_path):
    blob = _blob('L1_DC')
    palette = rows.palette_rgb(blob)
    for index in CAVE_IDS:
        flags, payload = _payload(blob, index)
        assert flags == 0x28E
        sprite = rows.decode_sprite(payload)
        values, _sec = _descriptor(blob, index)
        assert (sprite['width'], sprite['height']) == (values[1], values[2])
        assert sprite['count'] > 0
        # Colour alpha is 0 for both 0 and 1; index >= 2 stays opaque.
        rgba = rows.colour_rgba(sprite, palette)
        for pixel, index_byte in enumerate(sprite['indices']):
            alpha = rgba[pixel * 4 + 3]
            if index_byte <= 1:
                assert alpha == 0
            else:
                assert alpha == 255
        paths = rows.save_sprite(tmp_path, f'resource_{index}', sprite, palette)
        colour = Image.open(paths['colour'])
        shadow = list(Image.open(paths['shadow']).getdata())
        raw = list(Image.open(paths['index']).getdata())
        assert colour.mode == 'RGBA'
        assert raw == list(sprite['indices'])
        assert shadow == list(sprite['shadow_mask'])
        assert any(v == 255 for v in shadow)
        # Mask is grayscale, not an invented black RGBA shadow.
        assert Image.open(paths['shadow']).mode == 'L'


def test_alternate_header_flags_still_check_rows():
    blob = _blob('L4_HJ')
    sec = sections(blob)
    count = (sec[3] - sec[2]) // 56
    seen = set()
    for index in range(count):
        values = struct.unpack_from('<6H11I', blob, sec[2] + index * 56)
        if values[3] == 0x828E and values[4] == 1 and values[3] not in seen:
            flags, payload = _payload(blob, index)
        elif values[3] == 0x82C6 and values[3] not in seen:
            # First packed frame: descriptor size word is that frame's byte length.
            flags = values[3]
            start = sec[3] + values[7]
            payload = blob[start:start + values[12]]
        else:
            continue
        if values[3] not in seen:
            sprite = rows.decode_sprite(payload, expected_flags=flags)
            assert sprite['evidence']['flags'] == flags
            assert (sprite['width'], sprite['height']) == (values[1], values[2])
            assert len(sprite['indices']) == sprite['width'] * sprite['height']
            seen.add(flags)
        if seen == {0x828E, 0x82C6}:
            break
    assert seen == {0x828E, 0x82C6}
    with pytest.raises(ValueError):
        rows.decode_sprite(b'\x00' * 16, expected_flags=0x28E)


def test_initial_remap_row64_pinned_by_caller():
    blob = _blob('L1_DC')
    digest = hashlib.sha256(blob).hexdigest()
    row = rows.initial_remap_row(blob, digest)
    sec = sections(blob)
    assert row == blob[sec[4] + 0x4000:sec[4] + 0x4100]
    assert len(row) == 256
    with pytest.raises(ValueError):
        rows.initial_remap_row(blob, '0' * 64)
    flags, payload = _payload(blob, 193)
    sprite = rows.decode_sprite(payload, expected_flags=flags)
    block = rows.renderer_block(sprite, blob, digest)
    assert block['initial_remap'] == row
    assert block['shadow_mask'].count(255) == sprite['count']
