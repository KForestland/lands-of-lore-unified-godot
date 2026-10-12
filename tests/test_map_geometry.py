"""Structural checks for pinned area geometry export."""
import hashlib
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools' / 'lol2'))
import map_geometry
from lol2_source_format import parse_mix, u32

GAME = Path('/home/bob/lol2_out/museum_capture_20260913/game')
INVENTORY = json.loads(map_geometry.INVENTORY.read_text())


class MapGeometryTests(unittest.TestCase):
    def test_surface_snapshot_preserves_source_structure_and_ignores_caches(self):
        area = next(item for item in INVENTORY['areas'] if item['id'] == 'L3_DH')
        archive = (GAME / area['source']['file']).read_bytes()
        entry = next(item for item in parse_mix(archive) if item['key'] == area['source']['geometry_key'])
        raw = archive[entry['offset']:entry['offset'] + entry['size']]
        ro, nr = u32(raw, 12), u32(raw, 0x58)
        snapshot = bytearray(raw[ro:ro + nr * 44])
        original = bytes(snapshot)
        snapshot[0:4] = b'\xDE\xAD\xBE\xEF'
        snapshot[43] ^= 0xFF
        struct.pack_into('<h', snapshot, 20, -17)
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            map_geometry.export_geometry(GAME, 'L3_DH', out, region_snapshot=bytes(snapshot))
            geometry = json.loads((out / 'geometry.json').read_text())
            first = bytes.fromhex(geometry['regions'][0]['raw_hex'])
            self.assertEqual(first[:20], original[:20])
            self.assertEqual(first[43], original[43])
            self.assertEqual(struct.unpack_from('<h', first, 20)[0], -17)
            provenance = geometry['source']['captured_surface_state']
            self.assertEqual(provenance['region_table_sha256'], hashlib.sha256(snapshot).hexdigest())
            self.assertEqual(geometry['source']['entry_sha256'], area['source']['geometry_sha256'])
            bad = bytearray(snapshot)
            bad[12] ^= 1
            with self.assertRaisesRegex(ValueError, 'unsupported structural'):
                map_geometry.export_geometry(GAME, 'L3_DH', out, region_snapshot=bytes(bad))
            with self.assertRaisesRegex(ValueError, 'wrong length'):
                map_geometry.export_geometry(GAME, 'L3_DH', out, region_snapshot=bytes(snapshot[:-1]))

    def test_unknown_area_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                map_geometry.export_geometry(GAME, 'NO_SUCH', Path(tmp))

    def test_pinned_export_roundtrip_and_faces(self):
        area = next(item for item in INVENTORY['areas'] if item['id'] == 'L3_DH')
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            summary = map_geometry.export_geometry(GAME, 'L3_DH', out)
            self.assertTrue(summary['byte_round_trip'])
            self.assertFalse(summary['map_complete'])
            geometry = json.loads((out / 'geometry.json').read_text())
            faces = json.loads((out / 'faces.json').read_text())['faces']
            self.assertEqual(geometry['source']['sha256'], area['source']['sha256'])
            self.assertEqual(geometry['source']['geometry_key'], area['source']['geometry_key'])
            self.assertEqual(len(geometry['vertices_fixed']), area['counts']['vertices'])
            self.assertEqual(len(geometry['regions']), area['counts']['regions'])
            archive = (GAME / area['source']['file']).read_bytes()
            entry = next(item for item in parse_mix(archive) if item['key'] == area['source']['geometry_key'])
            raw = archive[entry['offset']:entry['offset'] + entry['size']]
            vo, nv = u32(raw, 4), u32(raw, 0x50)
            ro, nr = u32(raw, 12), u32(raw, 0x58)
            packed = b''.join(struct.pack('<ii', *vertex) for vertex in geometry['vertices_fixed'])
            self.assertEqual(packed, raw[vo:vo + nv * 8])
            self.assertEqual(b''.join(bytes.fromhex(region['raw_hex']) for region in geometry['regions']), raw[ro:ro + nr * 44])
            kinds = {face['kind'] for face in faces}
            self.assertTrue(kinds <= {'floor', 'ceiling', 'boundary', 'interior'})
            for face in faces:
                self.assertIn('region', face)
                self.assertIn('points', face)
                self.assertGreaterEqual(len(face['points']), 3)
                if face['kind'] in ('boundary', 'interior'):
                    self.assertIn('edge', face)
                if face['kind'] == 'interior':
                    self.assertIn(face['exposure'], ('step', 'upper'))
            ceiling_children = {
                child
                for chain in json.loads((out / 'topology.json').read_text())['unresolved_ceiling_subdivisions']
                for child in chain['children']
            }
            self.assertEqual(len(ceiling_children), summary['unresolved']['ceiling_subdivision_children'])
            self.assertGreater(len(ceiling_children), 0)
            surfaced = {face['region'] for face in faces if face['kind'] in ('floor', 'ceiling')}
            self.assertTrue(ceiling_children.isdisjoint(surfaced))
            floor_owners = {region['id'] for region in geometry['regions'] if region.get('floor_subdivisions')}
            floor_faces = {face['region'] for face in faces if face['kind'] == 'floor'}
            self.assertTrue(floor_owners.isdisjoint(floor_faces))


if __name__ == '__main__':
    unittest.main()
