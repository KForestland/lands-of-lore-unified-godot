#!/usr/bin/env python3
"""Compare the 3D index/depth review against an independent pixel reference."""
import argparse
import json
from pathlib import Path
from PIL import Image


def decoded(image):
    return [max(0, min(15, round((r - 64) / 12))) +
            16 * max(0, min(15, round((g - 64) / 12)))
            for r, g, _ in image.convert('RGB').getdata()]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    a = p.parse_args()
    fixture = a.project / 'assets/lol2/generated/special_pixel_review'
    captures = a.project / 'captures'
    background = Image.open(fixture / 'background.png').convert('RGB')
    source = Image.open(fixture / 'sprite.png').convert('RGB')
    # Rear object is behind the sprite; nearer object hides it. Their order
    # here is the analytic depth result, independent of GPU submission order.
    background.paste((19, 19, 19), (180, 80, 260, 200))
    background.paste((7, 7, 7), (230, 120, 310, 260))
    source.paste((0, 0, 0), (230, 120, 310, 260))
    report = {}
    for name, reference in [('background', background), ('source', source)]:
        actual = Image.open(captures / f'index_{name}.png')
        if actual.size != (640, 400):
            raise ValueError(f'{name}: wrong capture size')
        expected = [pixel[0] for pixel in reference.getdata()]
        report[name + '_index_mismatches'] = sum(x != y for x, y in zip(decoded(actual), expected))
    palette = list(Image.open(fixture / 'palette.png').convert('RGB').getdata())
    remap = [pixel[0] for pixel in Image.open(fixture / 'remap.png').convert('RGB').getdata()]
    expected = [palette[remap[d[0]] if s[0] == 1 else s[0] if s[0] else d[0]]
                for s, d in zip(source.getdata(), background.getdata())]
    actual = Image.open(captures / 'index_resolved.png').convert('RGB')
    if actual.size != (640, 400):
        raise ValueError('Wrong resolved size')
    report['resolved_rgb_mismatches'] = sum(x != y for x, y in zip(actual.getdata(), expected))
    report['pixels_per_buffer'] = 256000
    (captures / 'index_verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    if any(report[key] for key in report if key.endswith('mismatches')):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
