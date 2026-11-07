#!/usr/bin/env python3
"""Prepare initial attached scenery using explicit originals and published RE helpers.

The output must be fresh. Later decoding failures may leave partial output.
No motion, collision or native runtime acceptance is implied.
"""
import argparse
import os
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--re-root', type=Path, required=True)
    parser.add_argument('--area', required=True)
    parser.add_argument('--placement-kind', choices=['movable', 'static_assembly'], required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    if out.exists():
        parser.error('--out must be a fresh directory')
    for label, root in [('game', args.game_root), ('RE', args.re_root), ('tools', Path(__file__).parent)]:
        root = root.resolve()
        if not root.is_dir():
            parser.error(f'Missing {label} directory: {root}')
        if out == root or out in root.parents or root in out.parents:
            parser.error(f'Output overlaps {label} inputs')
    os.environ['LOL2_RE_ROOT'] = str(args.re_root.resolve())
    from lol2.map_primitive_geometry import export_area
    report = export_area(args.game_root, args.area, out, placement_kind=args.placement_kind)
    print(f"{args.area} {args.placement_kind}: {len(report['props'])} initial attached props")


if __name__ == '__main__':
    main()
