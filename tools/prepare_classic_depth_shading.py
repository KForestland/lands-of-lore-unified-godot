#!/usr/bin/env python3
"""Classic depth shading inputs for one level, read from the original game files.

Outputs (deterministic, into --out, default assets/lol2/generated/classic_depth_shading/):
  shade_<area>.png    256x64 grayscale: pixel (column=palette index, row=light row 0..63) = remapped index.
                      Rows 0..63 of the 66x256 shade section of the level texture file (G43, PROVEN).
  sectors_<area>.json region -> [ambient, fade_start, span] from the 26-byte light descriptor the region
                      names in word 12 (byte +24); ambient = signed byte +0x16, fade start = u16 +6, span = u16 +8.
  manifest.json       sha256 of every output and of the inputs.

Native formula these feed (0x1319B4, Opus decompile 2026-10-29; see HANDOFF_classic-depth-shading_20261029.txt):
  d     = trunc(sqrt(x*x + y*y + z*z))              camera-relative vertex, world units
  fade  = 1 if d - start < 1, 0 if d - start >= span, else 1 - (d - start) / span
  level = mult * ((fade * A) >> 7) + mult * (B >> 7), clamp 0..63 rows (0..0x3F0000 in 16.16)
  A     = ambient + plain light records; B = light records with flag 0x40 (light lists: run time, not produced).
The reader refuses a changed archive and exits non-zero without writing.
"""
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from lol2.map_materials import (load_inventory, area_by_id, identify_entries, decode_lzo_container,  # noqa: E402
                                parse_mix, sections, _png_gray_bytes, sha256_hex, require)

DEFAULT_OUT = HERE.parent / 'assets/lol2/generated/classic_depth_shading'
REGION_STRIDE = 44
DESCRIPTOR_STRIDE = 26


def u32(blob, offset):
    return struct.unpack_from('<I', blob, offset)[0]


def produce(game_root: Path, area_id: str) -> dict:
    source = area_by_id(load_inventory(), area_id)['source']
    mix = (game_root / source['file']).read_bytes()
    require(sha256_hex(mix) == source['sha256'], f'{area_id}: unsupported or changed archive')
    entries = parse_mix(mix)
    identity = identify_entries(mix, entries, source['geometry_key'])
    geometry_entry = next(e for e in entries if e['key'] == source['geometry_key'])
    geometry = mix[geometry_entry['offset']:geometry_entry['offset'] + geometry_entry['size']]
    require(sha256_hex(geometry) == source['geometry_sha256'], f'{area_id}: geometry differs')
    texture, _ = decode_lzo_container(mix, identity['texture_entry'])
    s = sections(texture)
    require(u32(texture, 0x54) == 0x4200 and u32(texture, 0x58) == 0x10000, 'shade/blend header sizes')
    require(u32(texture, 0x18) == s[4] and s[5] - s[4] == 66 * 256, 'shade section extent')
    shade = texture[s[4]:s[4] + 64 * 256]
    palette_at = u32(texture, 4)
    require(palette_at + 768 == s[4], 'palette sits against shade')
    dac = texture[palette_at:palette_at + 768]

    regions, region_at = u32(geometry, 0x58), u32(geometry, 12)
    table, count = u32(geometry, 0xA4), u32(geometry, 0xAC)
    require(table + count * DESCRIPTOR_STRIDE <= len(geometry), 'descriptor table extent')
    descriptors = []
    for i in range(count):
        record = geometry[table + i * DESCRIPTOR_STRIDE:table + (i + 1) * DESCRIPTOR_STRIDE]
        start, span = struct.unpack_from('<HH', record, 6)
        descriptors.append([struct.unpack_from('<b', record, 0x16)[0], start, span])
    sectors = {}
    for r in range(regions):
        index = struct.unpack_from('<H', geometry, region_at + r * REGION_STRIDE + 24)[0]
        require(index < count, f'region {r} names descriptor {index} outside table')
        sectors[str(r)] = descriptors[index]
    return dict(area=area_id, shade=shade, dac=dac, sectors=sectors, descriptor_count=count,
                inputs=dict(archive=source['file'], archive_sha256=source['sha256'],
                            geometry_sha256=source['geometry_sha256'],
                            texture_key=identity['texture_entry']['key'],
                            shade_rows_0_63_sha256=hashlib.sha256(shade).hexdigest(),
                            dac_sha256=hashlib.sha256(dac).hexdigest()))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game', type=Path, required=True, help='original game root (contains DAT/)')
    parser.add_argument('--area', action='append', default=None, help='level id, default L1_DC')
    parser.add_argument('--out', type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    areas = args.area or ['L1_DC']
    results = [produce(args.game.resolve(), a) for a in areas]  # all reads succeed before any write
    args.out.mkdir(parents=True, exist_ok=True)
    manifest = dict(schema=1, producer='tools/prepare_classic_depth_shading.py', areas={})
    for result in results:
        a = result['area']
        png = _png_gray_bytes(256, 64, result['shade'])
        sectors = json.dumps(dict(area=a, fields=['ambient', 'fade_start', 'span'], regions=result['sectors']),
                             indent=1, sort_keys=True).encode() + b'\n'
        (args.out / f'shade_{a}.png').write_bytes(png)
        (args.out / f'sectors_{a}.json').write_bytes(sectors)
        manifest['areas'][a] = dict(inputs=result['inputs'], descriptor_count=result['descriptor_count'],
                                    region_count=len(result['sectors']),
                                    outputs={f'shade_{a}.png': hashlib.sha256(png).hexdigest(),
                                             f'sectors_{a}.json': hashlib.sha256(sectors).hexdigest()})
    (args.out / 'manifest.json').write_text(json.dumps(manifest, indent=1, sort_keys=True) + '\n')
    print(json.dumps({a: v['outputs'] for a, v in manifest['areas'].items()}, sort_keys=True))


if __name__ == '__main__':
    main()
