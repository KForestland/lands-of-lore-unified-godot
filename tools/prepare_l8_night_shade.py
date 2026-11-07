#!/usr/bin/env python3
"""Per-row brightness of a level's native shade table (L8 night shading, docs/DEVIATIONS.md 2026-10-31).

The original darkens a surface by replacing every palette index with the index in row R of the level's 64x256 shade table
(row from the 0x1319B4 depth formula). The port's Act 2/3 textures are colour, so it cannot walk the table per pixel; this
producer measures what each row does to the palette on average: for row R and channel C, the sum of C over palette[table[R][i]]
divided by the sum of C over palette[i] (indices whose luminance is above 8/255; the near-black entries would only add noise).
Input: the all-maps export's environment/shade_indices.png (256x64 grey, the table) and environment/palette_dac.png (256x1 RGB,
the level palette), both written by tools/lol2/map_lighting.py from the level's texture section. Output: shade_rows.json with
the 64 RGB ratios, the input hashes and the scope; read by scripts/lol2/l8_night.gd into a 64x1 lookup texture.

  python3 tools/prepare_l8_night_shade.py --environment ~/lol2_out/all_maps_20260922/L8_SJ/environment \\
      --area L8_SJ --out assets/lol2/generated/darker_jungle_sky/shade_rows.json
"""
import argparse, hashlib, json
from pathlib import Path
from PIL import Image


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--environment', type=Path, required=True)
    p.add_argument('--area', required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    shade_bytes = (a.environment / 'shade_indices.png').read_bytes()
    palette_bytes = (a.environment / 'palette_dac.png').read_bytes()
    shade = Image.open(a.environment / 'shade_indices.png').convert('L')
    palette = Image.open(a.environment / 'palette_dac.png').convert('RGB')
    if shade.size != (256, 64) or palette.size != (256, 1):
        raise SystemExit(f'unexpected sizes: shade {shade.size}, palette {palette.size}')
    colours = [palette.getpixel((i, 0)) for i in range(256)]
    lum = [0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] for c in colours]
    rows = []
    for r in range(64):
        num = [0.0, 0.0, 0.0]
        den = [0.0, 0.0, 0.0]
        for i in range(256):
            if lum[i] <= 8:
                continue
            j = shade.getpixel((i, r))
            for c in range(3):
                num[c] += colours[j][c]
                den[c] += colours[i][c]
        rows.append([round(num[c] / den[c], 4) if den[c] else 0.0 for c in range(3)])
    out = dict(version=1, area=a.area, rows=rows,
               shade_sha256=hashlib.sha256(shade_bytes).hexdigest(), palette_sha256=hashlib.sha256(palette_bytes).hexdigest(),
               scope='Average RGB ratio of each native shade-table row over the level palette (indices with luminance > 8/255). '
                     'An adapter for colour textures: the original remaps palette indices per pixel; this scales the colour by the '
                     "row's average effect. Row 63 is the brightest row, row 0 black.")
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(out, indent=1) + '\n')
    print(f'{a.area}: 64 rows; row 63 {rows[63]}, row 52 {rows[52]}, row 30 {rows[30]}, row 16 {rows[16]}, row 0 {rows[0]}')


if __name__ == '__main__':
    main()
