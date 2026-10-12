"""Reject malformed banks and invalid requests before writing generated media."""
import struct
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from prepare_creature_audio_clips import sound_bank, stage_clips

class AudioInputs(unittest.TestCase):
    def test_invalid_requests_do_not_create_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'output'
            for request in [-1, 1179, 1.5, True, '1']:
                with self.subTest(request=request), self.assertRaises(ValueError):
                    stage_clips(root, 'audio', [request], game=Path(temp))
            self.assertFalse(root.exists())

    def test_folder_cannot_escape_generated_assets(self):
        with tempfile.TemporaryDirectory() as temp:
            for folder in ['/outside', '../outside', 'audio/../../outside']:
                with self.subTest(folder=folder), self.assertRaises(ValueError):
                    stage_clips(Path(temp), folder, [1], game=Path(temp))
            self.assertEqual(list(Path(temp).iterdir()), [])

    def test_missing_bank(self):
        with tempfile.TemporaryDirectory() as temp:
            (Path(temp) / 'LOCALLNG.MIX').write_bytes(struct.pack('<HI', 0, 0))
            with self.assertRaisesRegex(ValueError, 'exactly one'):
                sound_bank(temp)

    def test_duplicate_bank(self):
        with tempfile.TemporaryDirectory() as temp:
            data = struct.pack('<HI', 2, 2)
            data += struct.pack('<III', 1570429112, 0, 1)
            data += struct.pack('<III', 1570429112, 1, 1) + b'ab'
            (Path(temp) / 'LOCALLNG.MIX').write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'exactly one'):
                sound_bank(temp)

    def test_wrong_bank_hash(self):
        with tempfile.TemporaryDirectory() as temp:
            data = struct.pack('<HI', 1, 1) + struct.pack('<III', 1570429112, 0, 1) + b'x'
            (Path(temp) / 'LOCALLNG.MIX').write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'hash'):
                sound_bank(temp)

if __name__ == '__main__': unittest.main()
