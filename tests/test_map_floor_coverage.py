import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
from audit_map_floor_coverage import audit, has_area


class FloorCoverageTests(unittest.TestCase):
    def test_degenerate_and_nonfinite_polygons(self):
        self.assertTrue(has_area([[0, 0, 0], [2, 0, 0], [0, 0, 2]]))
        self.assertFalse(has_area([[0, 0, 0], [1, 0, 0], [2, 0, 0]]))
        self.assertFalse(has_area([[0, 0, 0], [float('nan'), 0, 0], [0, 0, 2]]))

    def test_missing_floor_and_explicit_floorless_are_distinct(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'geometry').mkdir()
            regions = []
            for rid, selector in [(0, 1), (1, 255)]:
                raw = bytearray(44)
                raw[32] = selector
                regions.append({'id': rid, 'raw_hex': raw.hex(), 'record_role': 'primary_region',
                                'floor_corners': [0]*4, 'ceiling_corners': [64]*4})
            (root/'geometry/geometry.json').write_text(json.dumps({'regions': regions}))
            (root/'review.json').write_text(json.dumps({'faces': [], 'materials': {}}))
            result = audit(root)
            self.assertEqual(result['missing_primary_floors'], [0])
            self.assertEqual(result['counts']['explicit_floorless_primary'], 1)


if __name__ == '__main__':
    unittest.main()
