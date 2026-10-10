"""Malformed compressed texture framing must fail before publishing a blob."""
import struct
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from lol2_texture_container import decode_lzo_container

class TextureBounds(unittest.TestCase):
    def decode(self, raw):
        return decode_lzo_container(raw,dict(index=0,key=1,offset=0,size=len(raw)))
    def test_invalid_decoded_lengths(self):
        for raw in [b'',struct.pack('<I',0),struct.pack('<I',64*1024*1024+1)]:
            with self.subTest(raw=raw),self.assertRaises(ValueError):self.decode(raw)
    def test_truncated_block_header(self):
        with self.assertRaises(ValueError):self.decode(struct.pack('<I',1)+b'\x01')
    def test_block_outside_entry(self):
        with self.assertRaises(ValueError):self.decode(struct.pack('<II',1,100)+b'abc')
    def test_invalid_compressed_data(self):
        with self.assertRaises(ValueError):self.decode(struct.pack('<II',1,3)+b'abc'+bytes(4))

if __name__=='__main__':unittest.main()
