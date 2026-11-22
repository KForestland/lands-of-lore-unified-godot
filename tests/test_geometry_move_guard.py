"""Synthetic coverage for the geometry-move guard (tools/prepare_lane_worktree.py geometry_move_problems), used by the
staging preflight and by tools/run_sharded_sweep.py, which refuses to start when a shard's generated move files do not
match their spec (void sweep 6d31407, 2026-11-14: stale area_moved.json, so the game loaded the original L10 map)."""
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from prepare_lane_worktree import geometry_move_problems  # noqa: E402


def sha(data):
    return hashlib.sha256(data).hexdigest()


def make_tree(root, area='L10_DC'):
    files = {
        f'assets/lol2/generated/maps/{area}/area.json': b'{"original": 1}',
        f'assets/lol2/generated/maps/{area}/area_moved.json': b'{"moved": 1}',
        f'assets/lol2/generated/creature_nav/{area}.json': b'{"nav": 1}',
        f'assets/lol2/generated/creature_nav/{area}.moved.json': b'{"nav": 2}',
        f'scripts/lol2/region_mover/{area}.moved.json': b'{}',
    }
    for name, data in files.items():
        (root / name).parent.mkdir(parents=True, exist_ok=True)
        (root / name).write_bytes(data)
    spec = {'area': area,
            'inputs': {'pack': sha(files[f'assets/lol2/generated/maps/{area}/area.json']),
                       'nav': sha(files[f'assets/lol2/generated/creature_nav/{area}.json'])},
            'outputs': {'pack': sha(files[f'assets/lol2/generated/maps/{area}/area_moved.json']),
                        'nav': sha(files[f'assets/lol2/generated/creature_nav/{area}.moved.json'])}}
    (root / 'scripts/lol2/geometry_moves').mkdir(parents=True, exist_ok=True)
    (root / f'scripts/lol2/geometry_moves/{area}.json').write_text(json.dumps(spec))


class GeometryMoveGuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        make_tree(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def test_matching_files_pass(self):
        self.assertEqual(geometry_move_problems(self.root), ([], ['L10_DC']))

    def test_stale_moved_pack_refused(self):
        # The 6d31407 case: the spec changed (tomb commit) but area_moved.json was generated from the old spec.
        (self.root / 'assets/lol2/generated/maps/L10_DC/area_moved.json').write_bytes(b'{"moved": "old"}')
        problems, _ = geometry_move_problems(self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn('moved pack', problems[0])
        self.assertIn('original map', problems[0])

    def test_stale_nav_and_missing_mover_refused(self):
        (self.root / 'assets/lol2/generated/creature_nav/L10_DC.moved.json').unlink()
        (self.root / 'scripts/lol2/region_mover/L10_DC.moved.json').unlink()
        problems, _ = geometry_move_problems(self.root)
        self.assertIn('moved nav', problems[0])
        self.assertIn('region-mover', problems[0])

    def test_changed_original_refused(self):
        (self.root / 'assets/lol2/generated/maps/L10_DC/area.json').write_bytes(b'{"original": 2}')
        self.assertIn('original pack', geometry_move_problems(self.root)[0][0])

    def test_no_specs_no_problems(self):
        empty = Path(self.tmp.name) / 'empty'
        empty.mkdir()
        self.assertEqual(geometry_move_problems(empty), ([], []))


if __name__ == '__main__':
    unittest.main()
