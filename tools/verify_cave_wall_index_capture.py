#!/usr/bin/env python3
"""Check the cave's GPU palette resolve against captured packed wall indices."""
import argparse
import json
import shutil
from pathlib import Path
from PIL import Image
from verify_index_buffer_capture import decoded


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument('--label', required=True, help='Capture label, e.g. checkpoint14')
    p.add_argument('--complete', action='store_true', help='Include roof tint and unresolved-material markers')
    a = p.parse_args()
    if not a.label.replace('_', '').replace('-', '').isalnum():
        p.error('Label must contain letters, numbers, underscore or hyphen')
    captures = a.project / 'captures'
    packed = Image.open(captures / 'cave_wall_indices.png')
    resolved = Image.open(captures / 'cave_wall_resolved.png').convert('RGB')
    if packed.size != resolved.size or min(packed.size) <= 0:
        raise ValueError('Capture dimensions differ')
    palette = list(Image.open(a.project / 'assets/lol2/generated/wall_indices/palette.png').convert('RGB').getdata())
    indices = decoded(packed)
    expected = []
    for index, (_, _, marker) in zip(indices, packed.convert('RGB').getdata()):
        rgb = palette[index]
        if a.complete and marker > 191:
            rgb = tuple(int(c * 0.65 + 0.5) for c in rgb)
        elif a.complete and marker > 63:
            rgb = (217, 38, 140)
        expected.append(rgb)
    mismatches = sum(pixel != rgb for pixel, rgb in zip(resolved.getdata(), expected))
    # Catch an empty/failed draw, without claiming this proves geometry parity.
    if len(set(indices)) < 16:
        raise ValueError('Capture lacks a useful wall texture sample')
    report = dict(label=a.label, width=packed.width, height=packed.height,
                  pixels=len(indices), unique_indices=len(set(indices)), rgb_mismatches=mismatches,
                  complete_static_pass=a.complete, scope='GPU palette resolve versus captured index buffer; not original-game screenshot or geometry parity.')
    destination = captures / 'indexed_walls' / a.label
    destination.mkdir(parents=True, exist_ok=True)
    for name in ['cave_wall_indices.png', 'cave_wall_resolved.png']:
        shutil.copy2(captures / name, destination / name)
    (destination / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    if mismatches:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
