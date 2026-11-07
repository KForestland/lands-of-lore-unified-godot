#!/usr/bin/env python3
"""Decode verified executioner outcome resources for local review."""
import hashlib
import json
import struct
from pathlib import Path
from lol2_creature_sprite_format import lcw, decode_blocks, decode_rows, group_frames  # published decoders
from lol2_material_format import sections, rgb_palette
from PIL import Image


def write_frames(blob, states, out):
    """Decode outcome resources into out. states: [{selector, resources:[one resource], action?}] in output order."""
    assert hashlib.sha256(blob).hexdigest() == 'c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
    sec = sections(blob)
    palette_offset = struct.unpack_from('<I', blob, 4)[0]
    palette = rgb_palette(blob[palette_offset:palette_offset + 768], 6)
    descriptors = {i: struct.unpack_from('<6H11I', blob, sec[2] + i * 56) for i in range((sec[3] - sec[2]) // 56)}
    groups = {g['base']: g for g in group_frames({i: d for i, d in descriptors.items() if d[3] == 0x1246})}
    out.mkdir(exist_ok=True)
    poses = []
    for state in states:
        assert len(state['resources']) == 1
        resource = state['resources'][0]
        resources = groups[resource]['frames'] if resource in groups else [resource]
        frames = []
        for index, ordinal in enumerate(resources):
            descriptor = descriptors[ordinal]
            position, size = sec[3] + descriptor[7], descriptor[12]
            assert sec[3] <= position and position + size <= len(blob)
            payload = blob[position:position + size]
            extra = {}
            if descriptor[3] == 0x1246:
                codebook_index = struct.unpack_from('<I', payload, 8)[0]
                offset, allocation, packed = struct.unpack_from('<III', blob, sec[9] + codebook_index * 12)
                assert sec[8] <= offset and offset + allocation <= sec[9] and 0 < packed <= allocation
                book = lcw(blob[offset:offset + packed])
                width, height, pixels, _, tail = decode_blocks(payload, book)
                extra = dict(codebook_sha256=hashlib.sha256(book).hexdigest(), unread_tail_bytes=tail)
            else:
                assert descriptor[3] == 0x28e and descriptor[4] == 1
                width, height, pixels, _ = decode_rows(payload)
            assert (width, height) == descriptor[1:3]
            rgba = bytes(channel for pixel in pixels for channel in (*palette[pixel * 3:pixel * 3 + 3], 255 if pixel else 0))
            name = f"selector_{state['selector']}_frame_{index:02}.png"
            Image.frombytes('RGBA', (width, height), rgba).save(out / name)
            frames.append(dict(frame=index, resource=ordinal, file=name, width=width, height=height,
                               payload_sha256=hashlib.sha256(payload).hexdigest(), rgba_sha256=hashlib.sha256(rgba).hexdigest(), **extra))
        poses.append(dict(selector=state['selector'], action=state.get('action'), frames=frames, count=len(frames)))
    return poses


def main():
    from verify_hive_executioner import OUT, ARCHIVE_SHA, EXE_HASH  # native audit records, legacy path only
    proof = json.loads((OUT / 'outcome_lookup_verified.json').read_text())
    assert proof['archive_sha256'] == ARCHIVE_SHA and proof['executable_sha256'] == EXE_HASH
    blob = (OUT / 'texture.bin').read_bytes()
    out = Path('~/lol2_out/hive_outcome_sprites_20260916')
    poses = write_frames(blob, proof['states'], out)
    report = dict(executable_sha256=EXE_HASH, archive_sha256=ARCHIVE_SHA, poses=poses,
                  scope='All source outcome resources decoded using bounded block/row decoders and the original palette. Index0 alpha is the review interpretation. No native playback cadence or complete outcome behavior is implied.')
    (out / 'review.json').write_text(json.dumps(report, indent=2) + '\n')
    cards = []
    for pose in poses:
        samples = sorted({0, pose['count'] // 2, pose['count'] - 1})
        cards.append(f"<section><h2>Selector {pose['selector']} · action {pose['action']} · {pose['count']} frames</h2>" + ''.join(f'<img alt="Frame {i}" src="{pose["frames"][i]["file"]}">' for i in samples) + '</section>')
    (out / 'review.html').write_text('<!doctype html><meta charset="utf-8"><title>Executioner outcome frames</title><style>body{background:#303840;color:white;font:18px sans-serif}img{image-rendering:pixelated;background:#4a535c;margin:8px}section{margin:24px}</style><h1>Executioner source outcome frames</h1><p>First, middle and final source frames. Timing and encounter integration remain separate.</p>' + ''.join(cards))
    print('PASS:', sum(p['count'] for p in poses), 'decoded source frames;', out / 'review.html')


if __name__ == '__main__':
    main()