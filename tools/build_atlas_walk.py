#!/usr/bin/env python3
"""Build tests/fixtures/atlas_jungle_start_walk.json: the earned walk from the Jungle arrival (353, -4909) to the clearing
outside the Huline Village gate (-1300, -5250; village_escape_route OUTSIDE), on the blocker-avoiding source-neighbour
graph of tools/build_jungle_blocker_routes.py. tests/atlas_readable_jungle_test.gd walks it and checks that the readable
Atlas shows only what that walk explored.

  python3 tools/build_atlas_walk.py --geometry ~/lol2_out/jungle_geometry_20260914/geometry.json [--check]
"""
import argparse, hashlib, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_jungle_blocker_routes as B

START = (353.0, -4909.0)
OUTSIDE = (-1300.0, -5250.0)
OUT = ROOT / 'tests/fixtures/atlas_jungle_start_walk.json'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--geometry', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    raw = args.geometry.read_bytes()
    if hashlib.sha256(raw).hexdigest() != B.GEOMETRY:
        print('unexpected geometry export', file=sys.stderr)
        return 2
    g = json.loads(raw)
    blockers = json.loads((ROOT / 'assets/lol2/generated/region_blockers/L4_HJ.json').read_text())
    graph = B.walkable(g, set(blockers['blocked_regions']))
    r = B.route(graph, B.locate(g, START), (B.locate(g, OUTSIDE), list(OUTSIDE)))
    r['scope'] = 'Jungle arrival -> clearing outside the village gate; source neighbour BFS with the blocker-avoiding graph (build_jungle_blocker_routes.py)'
    data = json.loads(json.dumps(r))
    if args.check:
        same = json.loads(OUT.read_text()) == data
        print(('SAME ' if same else 'DIFF ') + OUT.name)
        return 0 if same else 1
    OUT.write_text(json.dumps(data, indent=2) + '\n')
    print('wrote', OUT.name, len(r['regions']), 'regions, last point', r['points'][-1])
    return 0


if __name__ == '__main__':
    sys.exit(main())
