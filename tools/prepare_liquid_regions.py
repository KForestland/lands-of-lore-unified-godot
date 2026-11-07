#!/usr/bin/env python3
"""Liquid (water) regions of one area for the drowning rule (owner 2026-10-31: Luther drowns in the Cave river; the Lizard
form drowns in water everywhere).

Water regions = the regions whose floor faces in the staged pack use the area's water material(s) (the region record's
"floor preset" byte +0x20 selects a per-area floor entry; several presets share one water texture: the Jungle's 808 spans
presets 4-9/12/42/43). Each region gets its polygon (native x, -y: the scene x/z of the Act 1 hosts and act2_map), its floor
(the bed) and a SURFACE = the highest floor of its non-water neighbours (water fills to the bank; a region with no dry
neighbour keeps its own floor = depth 0). The native liquid depth/surface bytes are not decoded (Grok backlog, low
priority); this bank model is an adapter logged in DEVIATIONS. Nothing here says who drowns: liquid_drowning.gd does.

Usage: prepare_liquid_regions.py --area L4_HJ --geometry MAPS/L4_HJ/geometry/geometry.json --pack assets/.../jungle.json
       --materials 808 [--materials 38__front] --out assets/lol2/generated/liquid/L4_HJ.json
"""
import argparse
import hashlib
import json
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--area', required=True)
    p.add_argument('--geometry', type=Path, required=True)
    p.add_argument('--pack', type=Path, required=True, help='staged scene pack with floor faces carrying region + material')
    p.add_argument('--materials', action='append', required=True, help='water material key(s) as the pack names them')
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    g = json.loads(a.geometry.read_text())
    if g['source']['area_id'] != a.area:
        raise SystemExit(f"geometry is {g['source']['area_id']}, not {a.area}")
    pack = json.loads(a.pack.read_text())
    water = {}
    for f in pack.get('faces', []):
        if f.get('kind') == 'floor' and f.get('region') is not None and str(f.get('material')) in a.materials:
            water.setdefault(int(f['region']), str(f['material']))
    v = g['vertices_fixed']
    regions = {r['id']: r for r in g['regions']}
    out = []
    for rid in sorted(water):
        r = regions[rid]
        banks = [regions[n]['floor_base'] for n in r['neighbors'] if n is not None and n not in water]
        surface = max(banks) if banks else r['floor_base']
        out.append({'region': rid, 'material': water[rid], 'preset': int(bytes.fromhex(r['raw_hex'])[0x20]), 'bit0': bool(r['flags'] & 1),
                    'polygon': [[v[i][0] / 65536, -v[i][1] / 65536] for i in r['vertex_indices']],
                    'floor': r['floor_base'], 'ceiling': r['ceiling_base'], 'surface': surface, 'depth': surface - r['floor_base'],
                    'dry_neighbours': len(banks)})
    data = {'version': 1, 'area': a.area, 'geometry_sha256': g['source']['sha256'], 'pack_sha256': hashlib.sha256(a.pack.read_bytes()).hexdigest(),
            'materials': a.materials, 'regions': out,
            'scope': 'Water regions by floor material; surface = highest dry-neighbour floor (bank model, adapter). Polygons in native x / -y '
                     '(host scene x/z). Native liquid depth and the per-form rule bytes are not decoded.'}
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(data, indent=1) + '\n')
    depths = sorted(x['depth'] for x in out)
    print(f"{a.area}: {len(out)} water regions, bit0 {sum(1 for x in out if x['bit0'])}, depth median {depths[len(depths)//2] if depths else None} max {depths[-1] if depths else None} -> {a.out}")


if __name__ == '__main__':
    main()
