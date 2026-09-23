import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'tools'))
from audit_map_subdivision_coverage import boundary_metrics, measure


class SubdivisionCoverageTests(unittest.TestCase):
    parent = [(0, 0), (10, 0), (10, 10), (0, 10)]
    left = [(0, 0), (5, 0), (5, 10), (0, 10)]
    right = [(5, 0), (10, 0), (10, 10), (5, 10)]

    def test_exact_partition_and_reversed_winding(self):
        result = measure(self.parent, [self.left, self.right[::-1]])
        self.assertEqual(result['issues'], [])
        self.assertAlmostEqual(result['child_triangle_area'], 100)

    def test_missing_half(self):
        self.assertAlmostEqual(measure(self.parent, [self.left])['uncovered_area_lower_bound'], 50)

    def test_duplicate_half_is_detected_despite_matching_total_area(self):
        result = measure(self.parent, [self.left, self.left])
        self.assertAlmostEqual(result['pairwise_overlap_area'], 50)
        self.assertIn('overlapping child triangle projections', result['issues'])

    def test_shift_outside(self):
        shifted = [(x+5, y) for x, y in self.parent]
        result = measure(self.parent, [shifted])
        self.assertAlmostEqual(result['outside_area'], 50)
        self.assertAlmostEqual(result['uncovered_area_lower_bound'], 50)

    def test_shared_internal_edge_is_not_a_boundary(self):
        result = boundary_metrics(self.parent, [self.left, self.right])
        self.assertTrue(result['single_closed_outline'])
        self.assertEqual(result['boundary_edges'], 6)
        self.assertEqual(result['max_boundary_vertex_distance_to_parent_edge'], 0)

    def test_separated_pieces_are_not_one_outline(self):
        far_right = [(x+2, y) for x, y in self.right]
        result = boundary_metrics(self.parent, [self.left, far_right])
        self.assertFalse(result['single_closed_outline'])
        self.assertEqual(result['boundary_components'], 2)


if __name__ == '__main__':
    unittest.main()
