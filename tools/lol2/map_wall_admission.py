#!/usr/bin/env python3
"""Sector admission for all-FFFF class 0/8 wall owners.

Edges are header u32(0x34), count u32(0x7C), stride 8. References are header
u32(0x30). That binding is the walk at 0xE16C8: word [edge+4] offsets into the
reference blob, word [ref+2] is the region, region word +0x18 is the sector.
0xE24D4 copies each 26-byte descriptor to a 42-byte sector. 0xF584C uses word 0
and byte 0x17. 0xE16C8 uses word +2 and byte +0x18.

Initial admission is one 0xE16C8 from an arrival region's sector: that sector
plus the sectors named by its edges. It is not the transitive graph, and a
sector missing from the list is not marked unused.
"""
from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path

INVENTORY = Path(__file__).resolve().parents[2] / 'docs' / 'game-source-inventory.json'
GAME = Path('~/lol2_out/museum_capture_20260913/game')
MAPS = Path('~/lol2_out/all_maps_20260922')


def _u32(blob, offset):
    return struct.unpack_from('<I', blob, offset)[0]


def _mix_entry(archive, key):
    count, total = struct.unpack_from('<HI', archive)
    base = 6 + 12 * count
    if base + total != len(archive):
        raise ValueError('MIX size mismatch')
    for index in range(count):
        item_key, offset, size = struct.unpack_from('<III', archive, 6 + 12 * index)
        if item_key == key:
            return archive[base + offset:base + offset + size]
    raise ValueError(f'geometry key {key} missing')


def _sectors(raw):
    table, count = _u32(raw, 0xA4), _u32(raw, 0xAC)
    rows = []
    for index in range(count):
        base = table + index * 26
        record = raw[base:base + 26]
        first, edge = struct.unpack_from('<HH', record)
        rows.append(dict(
            index=index,
            first=first,
            edge=edge,
            region_count=record[23],
            edge_count=record[24],
        ))
    return rows


def _walk(raw, sector, regions):
    """Sectors named by one 0xE16C8 edge walk. Does not include the start."""
    edges, refs, edge_count = _u32(raw, 0x34), _u32(raw, 0x30), _u32(raw, 0x7C)
    if sector['edge'] == 65535 or sector['edge_count'] == 0:
        return []
    found = []
    remaining = sector['edge_count']
    index = sector['edge']
    steps = 0
    while True:
        remaining = (remaining - 1) & 0xFFFFFFFF
        if remaining == 0xFFFFFFFF:
            return found
        if index >= edge_count:
            raise ValueError(f"edge {index} past {edge_count}")
        offset = struct.unpack_from('<H', raw, edges + index * 8 + 4)[0]
        region = struct.unpack_from('<H', raw, refs + offset + 2)[0]
        if region >= len(regions):
            raise ValueError(f'reference region {region}')
        found.append(regions[region][12])
        remaining = (remaining + raw[edges + index * 8 + 7]) & 0xFFFFFFFF
        index += 1
        steps += 1
        if steps > edge_count:
            raise ValueError('edge walk did not terminate')


def _gap_records(area_id, maps_root=MAPS):
    walls = json.loads((maps_root / area_id / 'geometry' / 'source_walls.json').read_text())
    geometry = json.loads((maps_root / area_id / 'geometry' / 'geometry.json').read_text())
    arrivals = json.loads((maps_root / area_id / 'geometry' / 'arrivals.json').read_text())
    regions = {row['id']: row for row in geometry['regions']}
    records = []
    for issue in walls['issues']:
        if issue['reason'] != 'absent neighbor':
            continue
        code = issue['surface_code']
        if code is None or code & 0x10:
            continue
        region = regions[issue['region']]
        if any(neighbor is not None for neighbor in region['neighbors']):
            continue
        if (code & 12) not in (0, 8):
            continue
        records.append(issue)
    return records, regions, [row['region'] for row in arrivals['entries']]


def classify_area(area, archive, maps_root=MAPS):
    raw = _mix_entry(archive, area['source']['geometry_key'])
    if hashlib.sha256(raw).hexdigest() != area['source']['geometry_sha256']:
        raise ValueError(f"{area['id']} geometry hash mismatch")
    region_count = _u32(raw, 0x58)
    origin = _u32(raw, 0x0C)
    records = [struct.unpack_from('<22H', raw, origin + index * 44) for index in range(region_count)]
    sectors = _sectors(raw)
    cover = {}
    for sector in sectors:
        for region in range(sector['first'], sector['first'] + sector['region_count']):
            if region in cover:
                raise ValueError(f"{area['id']} overlapping sector {sector['index']}")
            cover[region] = sector['index']
    mismatched = 0
    uncovered = 0
    for index, record in enumerate(records):
        owner = cover.get(index)
        if owner is None:
            uncovered += 1
        elif owner != record[12]:
            mismatched += 1
    if mismatched:
        raise ValueError(f"{area['id']} {mismatched} regions disagree with word +0x18")
    edge_steps = 0
    named = set()
    for sector in sectors:
        linked = _walk(raw, sector, records)
        edge_steps += len(linked)
        named.update(linked)
    if edge_steps != _u32(raw, 0x7C):
        raise ValueError(f"{area['id']} edge steps {edge_steps} != header count")
    gaps, exported, arrival_regions = _gap_records(area['id'], maps_root)
    arrival_sectors = sorted({records[region][12] for region in arrival_regions})
    initial = set(arrival_sectors)
    for sector_id in arrival_sectors:
        initial.update(_walk(raw, sectors[sector_id], records))
    owners = {}
    for issue in gaps:
        region = issue['region']
        covered = cover.get(region)
        if covered is None:
            raise ValueError(f"{area['id']} gap region {region} is outside every sector run")
        sector = sectors[covered]
        slot = owners.setdefault(sector['index'], dict(
            sector=sector['index'],
            first=sector['first'],
            region_count=sector['region_count'],
            edge_count=sector['edge_count'],
            records=0,
            linked_primaries=0,
            on_initial_list=sector['index'] in initial,
            named_by_any_sector_edges=sector['index'] in named,
            static_placement_records=[],
        ))
        slot['records'] += 1
    for slot in owners.values():
        sector = sectors[slot['sector']]
        linked = 0
        for region in range(sector['first'], sector['first'] + sector['region_count']):
            if any(value != 65535 for value in records[region][2:6]):
                linked += 1
                if exported[region]['record_role'] != 'primary_region':
                    raise ValueError(f"{area['id']} linked region {region} is not primary")
        slot['linked_primaries'] = linked
    placement_offset, placement_count = _u32(raw, 0x14), _u32(raw, 0x60)
    if placement_offset + placement_count * 37 > len(raw):
        raise ValueError('Static placement table exceeds geometry source')
    for index in range(placement_count):
        region = struct.unpack_from('<H', raw, placement_offset + index * 37 + 10)[0]
        if region == 65535:
            continue
        if region >= len(records):
            raise ValueError('Static placement refers outside the region table')
        sector = records[region][12]
        if sector in owners:
            owners[sector]['static_placement_records'].append(index)
    record_total = sum(slot['records'] for slot in owners.values())
    with_primary = sum(slot['records'] for slot in owners.values() if slot['linked_primaries'])
    initial_records = sum(slot['records'] for slot in owners.values() if slot['on_initial_list'])
    return dict(
        area_id=area['id'],
        geometry_sha256=hashlib.sha256(raw).hexdigest(),
        scope='Stored sector-edge and arrival admission only. Absent membership does not prove unused geometry; direct runtime region admission remains unresolved.',
        regions=region_count,
        uncovered_regions=uncovered,
        sectors=len(sectors),
        edge_steps=edge_steps,
        arrival_regions=arrival_regions,
        arrival_sectors=arrival_sectors,
        initial_sector_count=len(initial),
        gap_records=record_total,
        gap_owner_sectors=len(owners),
        gap_records_sharing_sector_with_linked_primary=with_primary,
        gap_records_on_initial_arrival_list=initial_records,
        static_placements_on_gap_sectors=sum(len(row['static_placement_records']) for row in owners.values()),
        owners=sorted(owners.values(), key=lambda row: row['sector']),
    )


def main():
    inventory = json.loads(INVENTORY.read_text())
    rows = []
    for area in inventory['areas']:
        archive = (GAME / area['source']['file']).read_bytes()
        if hashlib.sha256(archive).hexdigest() != area['source']['sha256']:
            raise ValueError(f"{area['id']} archive hash mismatch")
        rows.append(classify_area(area, archive))
        row = rows[-1]
        counts = {}
        for owner in row['owners']:
            counts[owner['region_count']] = counts.get(owner['region_count'], 0) + owner['records']
        print(
            f"{row['area_id']} gaps {row['gap_records']} owners {row['gap_owner_sectors']} "
            f"uncovered_regions {row['uncovered_regions']} "
            f"with_linked_primary {row['gap_records_sharing_sector_with_linked_primary']} "
            f"on_initial_list {row['gap_records_on_initial_arrival_list']} "
            f"edges {row['edge_steps']} region_counts {counts}"
        )
    total = sum(row['gap_records'] for row in rows)
    shared = sum(row['gap_records_sharing_sector_with_linked_primary'] for row in rows)
    initial = sum(row['gap_records_on_initial_arrival_list'] for row in rows)
    print(f'total_gap_records {total} sharing_sector {shared} initial_list {initial}')
    return rows


if __name__ == '__main__':
    main()
