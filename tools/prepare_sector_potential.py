#!/usr/bin/env python3
"""Native potential-visibility sets per room (sector) of one Act 2/3 map, for region_visibility.gd islands mode.

Explicit inputs, no RE tree: the level archive (DAT/<AREA>.MIX) and the staged geometry.json (its 'source.entry' names
the geometry blob; its 'regions' carry the 22-word region records, word 12 = sector). The sector table (header u32 0xA4,
count u32 0xAC, 26-byte rows) and the edge walk (header u32 0x34 edges, u32 0x30 references, u32 0x7C count; native
0xE16C8, see tools/lol2/map_wall_admission.py) name, for every sector, the sectors its portal edges reach: the set the
original renderer may draw from that sector (tools/lol2/map_sector_visibility.py 'potential_sectors', conservative:
membership only, no screen clipping). Written as scripts/lol2/sector_potential/<AREA>.json.

  python3 tools/prepare_sector_potential.py --area L14_HT --archive /path/DAT/L14_HT.MIX \
      --geometry /path/L14_HT/geometry/geometry.json --out scripts/lol2/sector_potential/L14_HT.json
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lol2.map_wall_admission import _sectors, _walk  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--area', required=True)
    ap.add_argument('--archive', type=Path, required=True)
    ap.add_argument('--geometry', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    archive = args.archive.read_bytes()
    geometry = json.loads(args.geometry.read_text())
    entry = geometry['source']['entry']
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    if hashlib.sha256(raw).hexdigest() != geometry['source'].get('geometry_sha256', hashlib.sha256(raw).hexdigest()):
        print('geometry blob does not match the staged geometry', file=sys.stderr); return 2
    records = [struct.unpack('<22H', bytes.fromhex(r['raw_hex'])) for r in geometry['regions']]
    sectors = _sectors(raw)
    potential = {}
    for sector in sectors:
        named = sorted(set(_walk(raw, sector, records)) - {sector['index']})
        potential[str(sector['index'])] = named
    region_sector = [record[12] for record in records]
    # Native floor/ceiling base heights per region (geometry.json floor_base/ceiling_base): the pack omits the ceiling face of
    # a region whose ceiling has no surface material (the sky shows there in the original), so the host needs the height.
    region_floor = [int(r.get('floor_base', 0)) for r in geometry['regions']]
    region_ceiling = [int(r.get('ceiling_base') or 0) for r in geometry['regions']]   # a polygon-less region has no ceiling_base (L10)
    out = dict(version=2, area=args.area,
               archive_sha256=hashlib.sha256(archive).hexdigest(), geometry_sha256=hashlib.sha256(raw).hexdigest(),
               sectors=len(sectors), regions=len(records),
               binding='Sector table u32 0xA4/0xAC (26-byte rows); one 0xE16C8 edge walk per sector (edges u32 0x34, refs u32 0x30, '
                       'count u32 0x7C): the sectors its portal edges name. Membership only (the original clips portals on screen too).',
               region_sector=region_sector, region_floor=region_floor, region_ceiling=region_ceiling, potential=potential)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, separators=(',', ':')) + '\n')
    print(f'{args.area}: {len(sectors)} sectors, {len(records)} regions, '
          f'{sum(len(v) for v in potential.values())} potential links -> {args.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
