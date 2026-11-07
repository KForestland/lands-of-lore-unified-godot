#!/usr/bin/env python3
"""Export pinned L3_DH geometry using the cave's shared static interpretations.

Requires the companion RE tools. Preserves source coordinates and unknown words;
markers are evidence, not an inferred player spawn. Does not modify game files.
"""
import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

ARCHIVE_SHA = 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'
GEOMETRY_KEY = 3106551060


def export(game_root, re_tools, out, *, level="museum"):
    profiles = {
        "museum": ("L3_DH.MIX", ARCHIVE_SHA, GEOMETRY_KEY, (2162, 1499, 5300, 49290)),
        "jungle": ("L4_HJ.MIX", "517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f",
                   3710797084, (6211, 4787, 5300, 108026)),
        "hive": ("L5_HC.MIX", "a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8",
                 3776990464, (2001, 1292, 5300, 44194)),
    }
    archive_name, expected_hash, geometry_key, expected_header = profiles[level]
    sys.path.insert(0, str(re_tools))
    from lol2_extract_draracle_geometry import parse_mix, u32, s16, slope_corners, audit, export_svg
    from lol2_draracle_openings import interpret, obj_preview

    src = game_root / 'DAT' / archive_name
    archive = src.read_bytes()
    if hashlib.sha256(archive).hexdigest() != expected_hash:
        raise ValueError('Unsupported or changed archive; expected pinned original fixture')
    entry = next(e for e in parse_mix(archive) if e['key'] == geometry_key)
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    nv, nr, vo, ro = (u32(raw, p) for p in (0x50, 0x58, 4, 12))
    if (u32(raw, 0), nv, nr, vo, ro) != (18, *expected_header):
        raise ValueError('Geometry header mismatch')
    if vo + nv * 8 > len(raw) or ro + nr * 44 > len(raw):
        raise ValueError('Geometry table exceeds entry')
    vertices = list(struct.iter_unpack('<ii', raw[vo:vo + nv * 8]))
    records = [struct.unpack_from('<22H', raw, ro + i * 44) for i in range(nr)]
    regions = []
    for i, r in enumerate(records):
        if any(v >= nv for v in r[6:10]):
            raise ValueError('Vertex reference outside table')
        if any(n != 65535 and n >= nr for n in r[2:6]):
            raise ValueError('Neighbor reference outside table')
        regions.append(dict(
            id=i, source_offset=entry['offset'] + ro + i * 44,
            raw_hex=raw[ro + i * 44:ro + (i + 1) * 44].hex(),
            vertex_indices=list(r[6:10]),
            neighbors=[None if n == 65535 else n for n in r[2:6]],
            floor_base=s16(r[10]), ceiling_base=s16(r[11]),
            floor_corners=slope_corners(records, i),
            ceiling_corners=slope_corners(records, i, True),
            flags=r[14], unknown_words=list(r[12:]),
            floor_slope=bool(r[14] & 4), ceiling_slope=bool(r[14] & 8)))
    topology, corrected = interpret(vertices, records, regions)
    raw_audit, edges = audit(vertices, records, regions)
    count, start = u32(raw, 0xc4), u32(raw, 0xc8)
    names = start + count * 8
    if names + count * 26 != u32(raw, 0xdc):
        raise ValueError('Marker block bounds mismatch')
    markers = []
    for i in range(count):
        x, y, region, flags = struct.unpack_from('<hhHH', raw, start + i * 8)
        if region != 65535 and region >= nr:
            raise ValueError('Marker region outside table')
        markers.append(dict(id=i, x=x, y=y, region=None if region == 65535 else region,
                            flags_uninterpreted=flags,
                            name=raw[names + i * 26:names + (i + 1) * 26].split(b'\0')[0].decode('ascii'),
                            source_offset=entry['offset'] + start + i * 8))
    # Independent byte round trips catch loss of signed coordinates or record data.
    if b''.join(struct.pack('<ii', *v) for v in vertices) != raw[vo:vo + nv * 8]:
        raise ValueError('Vertex round trip failed')
    if b''.join(bytes.fromhex(r['raw_hex']) for r in corrected) != raw[ro:ro + nr * 44]:
        raise ValueError('Region round trip failed')
    out.mkdir(parents=True, exist_ok=True)
    def write(name, data):
        (out / name).write_text(json.dumps(data, indent=2) + '\n')
    write('geometry.json', dict(
        schema='lol2-museum-geometry-v1',
        source=dict(file='DAT/' + archive_name, sha256=expected_hash, entry=entry,
                    entry_sha256=hashlib.sha256(raw).hexdigest()),
        vertices_fixed=vertices, regions=corrected,
        scope='Original coordinates and reused static region interpretation. '
              'Materials, native arrival pose, runtime collision and scripts are not verified.'))
    write('markers.json', dict(markers=markers, player_spawn=None,
                              scope='Stored names and positions; no marker assigned as player spawn.'))
    write('topology.json', topology)
    write('raw_audit.json', raw_audit)
    obj_preview(out / f'{level}_surfaces.obj', vertices, corrected)
    export_svg(out, vertices, regions, edges)
    (out / 'draracle_footprint.svg').rename(out / f'{level}_footprint.svg')
    summary = dict(vertices=nv, regions=nr, markers=count,
                   byte_round_trip=True, **topology['summary'])
    write('summary.json', summary)
    write('manifest.json', {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in sorted(out.iterdir()) if p.is_file() and p.name != 'manifest.json'})
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--re-tools', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--level', choices=['museum', 'jungle', 'hive'], default='museum')
    args = parser.parse_args()
    print(json.dumps(export(args.game_root, args.re_tools, args.out, level=args.level), indent=2))


if __name__ == '__main__':
    main()
