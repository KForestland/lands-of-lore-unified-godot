"""Portable checks for ceiling audit admission and negative findings."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from audit_map_ceiling_coverage import audit


class CeilingCoverageTests(unittest.TestCase):
    def fixture(self, root, missing=False):
        regions = []
        for rid, floor_selector, ceiling_selector in [(0, 0, 1), (1, 1, 255), (2, 0, 255)]:
            raw = bytearray(44)
            raw[32], raw[34] = floor_selector, ceiling_selector
            regions.append({'id': rid, 'raw_hex': raw.hex(), 'standalone_ceiling': True,
                            'ceiling_corners': [64]*4})
        geometry = {'regions': regions, 'ceiling_subdivisions':
                    {'owners': [0], 'children': [1], 'unresolved_children': []}}
        faces = [] if missing else [{'kind': 'ceiling', 'region': 1, 'material': '7',
                                    'points': [[0, 64, 0], [16, 64, 0], [0, 64, 16]]}]
        (root/'geometry').mkdir()
        (root/'geometry/geometry.json').write_text(json.dumps(geometry))
        (root/'review.json').write_text(json.dumps({'faces': faces, 'materials': {'7': 'texture.png'}}))

    def test_child_uses_floor_selector_and_owner_plane_is_suppressed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            result = audit(root)
            self.assertEqual(result['expected_ceiling_regions'], 1)
            self.assertEqual(result['missing_ceilings'], [])
            self.assertEqual(result['unexpected_ceilings'], [])

    def test_missing_child_surface_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root, missing=True)
            result = audit(root)
            self.assertEqual(result['missing_ceilings'],
                             [{'region': 1, 'reason': 'expected ceiling face absent'}])


if __name__ == '__main__':
    unittest.main()
