"""Malformed archive boundaries must fail before data is exposed to extractors."""
import struct
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from lol2_source_format import parse_mix

class MixBounds(unittest.TestCase):
    def test_offsets_are_archive_relative(self):
        data = struct.pack("<HI", 2, 5) + struct.pack("<III", 9, 3, 2) + struct.pack("<III", 8, 0, 3) + b"abcde"
        entries = parse_mix(data)
        self.assertEqual([data[e["offset"]:e["offset"]+e["size"]] for e in entries], [b"de", b"abc"])
        self.assertEqual([e["key"] for e in entries], [9, 8])

    def test_empty_archive(self):
        self.assertEqual(parse_mix(struct.pack("<HI", 0, 0)), [])

    def test_truncated_header(self):
        for size in range(6):
            with self.subTest(size=size), self.assertRaises(ValueError):
                parse_mix(bytes(size))

    def test_truncated_index_and_trailing_data(self):
        for data in [struct.pack("<HI", 1, 0), struct.pack("<HI", 0, 0) + b"x"]:
            with self.subTest(data=data), self.assertRaises(ValueError):
                parse_mix(data)

    def test_entry_outside_data(self):
        data = struct.pack("<HI", 1, 2) + struct.pack("<III", 1, 1, 2) + b"ab"
        with self.assertRaises(ValueError): parse_mix(data)

    def test_overlapping_entries(self):
        data = struct.pack("<HI", 2, 3) + struct.pack("<III", 1, 0, 2) + struct.pack("<III", 2, 1, 2) + b"abc"
        with self.assertRaises(ValueError): parse_mix(data)

if __name__ == "__main__": unittest.main()
