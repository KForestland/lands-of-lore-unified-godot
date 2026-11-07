#!/usr/bin/env python3
"""Per-area sky/background candidates from proven metadata presets and the texture DEFAULT record.

Metadata preset grammar is the one checked in
lol2_extract_surface_presets.py: u32 at +4 is the 24-byte record start, u32 at +0x3c
is the count, and u32 at +8 equals start + count*24 + count*22 (22-byte names).
The signed short at record+4 is the resource index. On L1_DC that index is the
descriptor ordinal (lol2_bind_floor_materials.py). This tool applies that same
ordinal only when the name is sky* or background* and the descriptor decodes with
the existing 0xE1/0x8B slot walker. It does not treat geometry+0x70 as a color.

Twelve texture containers also carry one type-1 record named DEFAULT, payload
length 385392. Header dimensions identify a 1280 by 300 indexed panorama:
pixels start at record+0x14c and end exactly at the source PCX path. Images
use the area palette. The geometry environment block supplies the native vertical origin.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools' / 'lol2'))
import map_materials as mm  # noqa: E402

PRESET_RECORD = 24
PRESET_NAME = 22
DEFAULT_TYPE = 1
DEFAULT_PAYLOAD = 385392
DEFAULT_PATH_REL = 384332
SKY_NAME_PREFIXES = ('sky', 'background', 'backgrnd', 'backgrn')


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def presets(meta: bytes) -> list[dict]:
    start, name_end, count = struct.unpack_from('<I', meta, 4)[0], struct.unpack_from('<I', meta, 8)[0], struct.unpack_from('<I', meta, 0x3C)[0]
    mm.require(0 < count < 10000 and start + count * PRESET_RECORD + count * PRESET_NAME == name_end <= len(meta),
               'metadata preset/name boundary mismatch')
    names = start + count * PRESET_RECORD
    rows = []
    for index in range(count):
        record = meta[start + index * PRESET_RECORD:start + (index + 1) * PRESET_RECORD]
        name = meta[names + index * PRESET_NAME:names + (index + 1) * PRESET_NAME].split(b'\0', 1)[0].decode('ascii')
        resource_index = struct.unpack_from('<h', record, 4)[0]
        rows.append(dict(index=index, name=name, resource_index=resource_index))
    return rows


def sky_presets(rows: list[dict]) -> list[dict]:
    found = []
    for row in rows:
        key = row['name'].lower()
        if key.startswith(SKY_NAME_PREFIXES):
            found.append(row)
    return found


def default_record(blob: bytes) -> dict | None:
    """Type-1 DEFAULT record: dword 1, dword 385392, name at +16, span inside the blob."""
    cursor = 0
    needle = b'DEFAULT\x00'
    while True:
        at = blob.find(needle, cursor)
        if at < 0 or at < 16:
            return None
        base = at - 16
        kind, size = struct.unpack_from('<II', blob, base)
        if kind == DEFAULT_TYPE and size == DEFAULT_PAYLOAD and base + 16 + size <= len(blob):
            path_at = base + DEFAULT_PATH_REL
            raw = blob[path_at:path_at + 160]
            end = raw.find(b'\x00')
            mm.require(end > 0, 'DEFAULT path is not a C string')
            path = raw[:end].decode('ascii')
            mm.require(path.endswith('.pcx') and '\\' in path, 'DEFAULT path is not a PCX source path')
            payload = blob[base:base + 16 + size]
            return dict(offset=base, payload_bytes=16 + size, path=path, path_offset=path_at,
                        sha256=sha256_hex(payload))
        cursor = at + 1


def _decode_descriptor(blob: bytes, index: int) -> dict:
    offsets = mm.sections(blob)
    palette_offset = struct.unpack_from('<I', blob, 4)[0]
    mm.require(palette_offset + 768 == offsets[4], 'palette boundary')
    table, payload = offsets[2], offsets[3]
    mm.require(table > 0 and payload > table and (payload - table) % 56 == 0, 'descriptor table extent')
    count = (payload - table) // 56
    mm.require(0 <= index < count, 'resource index outside descriptor table')
    end = min((value for value in offsets if value > payload), default=len(blob))
    record = mm.generic_variant_record(blob, table, payload, end, index)
    rgb = mm.rgb_palette(blob[palette_offset:palette_offset + 768], 6)
    return dict(record=record, rgb=rgb, descriptor_count=count)


def export_panorama(blob: bytes, embedded: dict, out: Path) -> dict:
    """Bounded row image identified by the DEFAULT record's own dimensions.

    All twelve local records declare 1280x300 at +0x128/+0x12c. The pixels
    begin at +0x14c and end exactly at the original PCX filename. This recovers
    the image; camera projection and the other header fields remain separate.
    """
    base = embedded['offset']
    width, height = struct.unpack_from('<2I', blob, base + 0x128)
    mm.require((width, height) == (1280, 300), 'unsupported panorama dimensions')
    start, end = base + 0x14c, base + 0x14c + width * height
    mm.require(end == embedded['path_offset'] and end <= base + embedded['payload_bytes'],
               'panorama pixels do not end at the PCX path')
    pixels = blob[start:end]
    palette_offset = struct.unpack_from('<I', blob, 4)[0]
    rgb = mm.rgb_palette(blob[palette_offset:palette_offset + 768], 6)
    (out/'panorama.png').write_bytes(mm.png_rgb(width, height, mm.colorize(pixels, rgb)))
    (out/'panorama_indices.png').write_bytes(mm._png_gray_bytes(width, height, pixels))
    return dict(image='panorama.png', indices='panorama_indices.png', width=width, height=height,
                source_pixel_offset=start, source_pixel_size=len(pixels),
                pixels_sha256=sha256_hex(pixels), header_hex=blob[base+0x120:base+0x14c].hex(),
                source_path=embedded['path'], layout='row-major indexed image',
                projection='review cylindrical projection; native horizon and yaw alignment pending')


def geometry_sky_origin(geometry: bytes) -> dict:
    offset = struct.unpack_from('<I', geometry, 0x28)[0]
    mm.require(offset >= 0x244 and offset + 0x218 <= len(geometry), 'sky environment block extent')
    return dict(vertical_origin=struct.unpack_from('<i', geometry, offset + 0x18)[0],
                environment_block_offset=offset, field_offset=0x18,
                binding='native 9CD6C..9CE0D loads geometry environment+0x18 into 273C4; sky 5A468..5A69C',
                projection='native 640x400 raster sky; half-pixel source steps, 1280-pixel horizontal wrap')


def export_area(area_id: str, meta: bytes, blob: bytes, out: Path, geometry: bytes | None = None) -> dict:
    rows = presets(meta)
    named = sky_presets(rows)
    embedded = default_record(blob)
    images = []
    unresolved = []
    out.mkdir(parents=True, exist_ok=True)
    panorama = None
    if embedded is not None:
        try:
            panorama = export_panorama(blob, embedded, out)
            if geometry is not None:
                panorama.update(geometry_sky_origin(geometry))
        except ValueError as exc:
            unresolved.append(dict(kind='panorama', reason=str(exc)))
    for row in named:
        if row['resource_index'] < 0:
            unresolved.append(dict(name=row['name'], resource_index=row['resource_index'],
                                   reason='negative resource index is the animation-table case left unresolved by lol2_bind_floor_materials.py'))
            continue
        try:
            decoded = _decode_descriptor(blob, row['resource_index'])
        except (ValueError, struct.error) as exc:
            unresolved.append(dict(name=row['name'], resource_index=row['resource_index'], reason=str(exc)))
            continue
        record = decoded['record']
        frames = [image for image in record['images'] if image['level'] == 0]
        mm.require(frames, 'decoded sky descriptor has no level-0 frame')
        written = []
        for frame in frames:
            pixels = mm.image_rows(frame)
            png = mm.png_rgb(frame['width'], frame['height'], mm.colorize(pixels, decoded['rgb']))
            name = f"{row['name']}_v{frame['variant']}.png"
            (out / name).write_bytes(png)
            written.append(dict(file=name, variant=frame['variant'], width=frame['width'], height=frame['height'],
                                 sha256=sha256_hex(png), kind=frame['kind']))
        images.append(dict(
            preset_index=row['index'], name=row['name'], resource_index=row['resource_index'],
            descriptor_identifier=record['identifier'], flags=record['flags'],
            variant_count=record['variant_count'], frames=written,
            binding='metadata resource_index short at preset+4; L1_DC native consumer uses that short as the descriptor ordinal. This area was not re-replayed.',
            projection='unresolved; image is the named preset frame, not a panorama placement'))
    if not named and embedded is None:
        gap = 'no sky/background preset name and no type-1 DEFAULT record'
    elif not images and panorama is None:
        gap = 'no sky image exported; see unresolved and default_record'
    else:
        gap = None
    report = dict(
        area_id=area_id,
        preset_count=len(rows),
        sky_presets=named,
        images=images,
        panorama=panorama,
        unresolved=unresolved,
        default_record=None if embedded is None else dict(
            offset=embedded['offset'], payload_bytes=embedded['payload_bytes'], path=embedded['path'],
            path_offset=embedded['path_offset'], sha256=embedded['sha256'],
            unresolved_reason='native source origin bound; rotated free-camera pitch and bottom clipping remain modern approximations' if geometry is not None else 'geometry environment origin not supplied'),
        open_sky='source panorama' if panorama else 'named preset image' if images else 'unresolved',
        gap=gap,
        rejected_color_guess='geometry header +0x70 is a placement count, not a background color',
    )
    (out / 'environment.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def export_all(game_root: Path, texture_root: Path, out_root: Path) -> list[dict]:
    inventory = mm.load_inventory()
    reports = []
    for area in inventory['areas']:
        area_id = area['id']
        mix = (game_root / area['source']['file']).read_bytes()
        mm.require(sha256_hex(mix) == area['source']['sha256'], f'{area_id} archive changed')
        entries = mm.parse_mix(mix)
        identity = mm.identify_entries(mix, entries, area['source']['geometry_key'])
        meta_entry = identity['metadata_entry']
        meta = mix[meta_entry['offset']:meta_entry['offset'] + meta_entry['size']]
        texture_path = texture_root / area_id / 'materials/texture.bin'
        if not texture_path.exists():
            texture_path = texture_root / area_id / 'texture.bin'
        blob = texture_path.read_bytes()
        entry = identity['geometry_entry']
        geometry = mix[entry['offset']:entry['offset'] + entry['size']]
        reports.append(export_area(area_id, meta, blob, out_root / area_id / 'environment', geometry))
    return reports


def export_from_game(game_root: Path, area_id: str, material_root: Path, out: Path) -> dict:
    area = mm.area_by_id(mm.load_inventory(), area_id)
    archive = (game_root/area['source']['file']).read_bytes()
    mm.require(sha256_hex(archive) == area['source']['sha256'], 'environment source archive changed')
    metadata = []
    for entry in mm.parse_mix(archive):
        data = archive[entry['offset']:entry['offset'] + entry['size']]
        if len(data) >= 516 and struct.unpack_from('<2I', data) == (18, 516):
            metadata.append(data)
    mm.require(len(metadata) == 1, 'environment metadata entry is ambiguous')
    identity = mm.identify_entries(archive, mm.parse_mix(archive), area['source']['geometry_key'])
    entry = identity['geometry_entry']
    geometry = archive[entry['offset']:entry['offset'] + entry['size']]
    return export_area(area_id, metadata[0], (material_root/'texture.bin').read_bytes(), out, geometry)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--texture-root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    reports = export_all(args.game_root, args.texture_root, args.out)
    for report in reports:
        print(report['area_id'], 'images', len(report['images']), 'default', bool(report['default_record']), 'gap', report['gap'])


if __name__ == '__main__':
    main()
