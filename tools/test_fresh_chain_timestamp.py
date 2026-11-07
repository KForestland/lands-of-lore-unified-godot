"""A complete baseline in the receipt's start second must not fail for fractional precision."""
import unittest
from audit_fresh_chain_progress import baseline_within_start_time

class TimestampPrecisionTests(unittest.TestCase):
    def test_second_resolution_boundaries(self):
        start = 1791525185.0
        for offset, expected in [(-1, True), (0, True), (.083234565, True), (.999999, True), (1, False), (1.1, False)]:
            with self.subTest(offset=offset):
                self.assertEqual(baseline_within_start_time(start + offset, start), expected)

if __name__ == '__main__':
    unittest.main()
