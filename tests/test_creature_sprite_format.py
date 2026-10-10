"""Boundary checks for the shared indexed-sprite readers; no game assets."""
import struct
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from lol2_creature_sprite_format import lcw, decode_rows, read_events, sections, rgb_palette, partition_entities

class SpriteBounds(unittest.TestCase):
    def test_lcw_literal_and_overlapping_copy(self):
        self.assertEqual(lcw(b'\x81a\x00\x01\x80'), b'aaaa')
        for data in [b'\x81', b'\x00\x01\x80', b'\x80x', b'\x81a']:
            with self.subTest(data=data), self.assertRaises(ValueError): lcw(data)

    def test_indexed_row_preserves_special_pixels(self):
        data = struct.pack('<4H', 0x28e, 3, 1, 7) + struct.pack('<HH', 0xc000, 3) + bytes([0,1,2])
        self.assertEqual(decode_rows(data, allow_special=True), (3,1,bytes([0,1,2]),1))
        with self.assertRaises(ValueError): decode_rows(data)
        with self.assertRaises(ValueError): decode_rows(data[:-1], allow_special=True)

    def test_events_require_terminator_and_bounds(self):
        data = bytes([2,3,7,0,0,0,0,0]) + bytes(8)
        rows, end = read_events(data, 0, 2, 0)
        self.assertEqual((rows[0]['value_word'], end), (7,1))
        with self.assertRaises(ValueError): read_events(data[:8],0,1,0)
        with self.assertRaises(ValueError): read_events(data,0,2,2)

    def test_sections_reject_external_offsets(self):
        data = struct.pack('<6I',4,0,24,24,24,24)
        self.assertEqual(sections(data),(24,24,24,24))
        with self.assertRaises(ValueError): sections(data[:-1])
        with self.assertRaises(ValueError): sections(struct.pack('<6I',4,0,25,24,24,24))

    def test_palette_rejects_non_dac_values(self):
        self.assertEqual(rgb_palette(bytes([63])*768,6),bytes([255])*768)
        with self.assertRaises(ValueError): rgb_palette(bytes([64])*768,6)
        with self.assertRaises(ValueError): rgb_palette(bytes(767),6)

    def test_entity_partition_rejects_partial_record(self):
        with self.assertRaises(ValueError): partition_entities(bytes(146),b'')
        with self.assertRaises(ValueError): partition_entities(bytes([1])*147,b'')

if __name__ == '__main__': unittest.main()
