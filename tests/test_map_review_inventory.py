"""Synthetic coverage for the map review inventory."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_map_review_inventory as inventory


def _region(region_id, role, neighbors, owner=None, vertex_indices=None, floor=-10, ceiling=20):
    return {
        'id': region_id,
        'record_role': role,
        'neighbors': neighbors,
        'owner': owner,
        'vertex_indices': [0, 1] if vertex_indices is None else vertex_indices,
        'floor_corners': [floor, floor, floor, floor],
        'ceiling_corners': [ceiling, ceiling, ceiling, ceiling],
    }


def _write_area(root: Path, name: str, regions, arrivals=None, faces=None, issues=None,
                placements=None, state_faces=None, state_sprites=None, labels=None):
    area = root / name
    (area / 'geometry').mkdir(parents=True)
    geometry = {
        'schema': 'lol2-area-geometry-v1',
        'source': {
            'area_id': name,
            'name': name,
            'file': f'DAT/{name}.MIX',
            'sha256': 'abc',
            'geometry_key': 1,
            'geometry_sha256': 'def',
            'entry_sha256': 'def',
        },
        'vertices_fixed': [[0, 0], [65536, -131072]],
        'regions': regions,
    }
    (area / 'geometry' / 'geometry.json').write_text(json.dumps(geometry), encoding='utf-8')
    (area / 'geometry' / 'arrivals.json').write_text(json.dumps({
        'entries': arrivals or [],
        'adjacent_labels': ['Start', 'Named room'] if labels is None else labels,
        'label_binding': 'unbound',
    }), encoding='utf-8')
    (area / 'review.json').write_text(json.dumps({
        'id': name,
        'name': name,
        'faces': faces or [],
        'geometry_issues': issues or [],
        'movable_placements': placements or [],
        'movable_state_faces': state_faces or [],
        'attached_state_props': state_sprites or [],
        'summary': {'ready_for_content': True, 'visual_qa': 'accepted'},
    }), encoding='utf-8')
    return area


class ReviewInventoryTests(unittest.TestCase):
    def _fixture(self):
        regions = [
            _region(0, 'primary_region', [2, None, None, None]),
            _region(2, 'primary_region', [None, None, None, None]),
            _region(5, 'primary_region', [None, None, None, None], vertex_indices=[1]),
            _region(9, 'floor_subdivision', [0, None], owner=0, vertex_indices=[]),
        ]
        arrivals = [
            {'index': 3, 'region': 0},
            {'index': 1, 'region': 9},
            {'index': 4, 'region': None},
            {'index': 8, 'region': 404},
        ]
        faces = [
            {'kind': 'floor', 'region': 0},
            {'kind': 'ceiling', 'region': 2},
            {'kind': 'source_wall', 'region': 0},
            {'kind': 'source_wall', 'region': 5},
            {'kind': 'floor', 'region': 9},
            {'kind': 'movable', 'region': None, 'placement': 1, 'child': 7, 'child_mask': 1},
            {'kind': 'movable', 'region': None, 'placement': 1, 'child': 7, 'child_mask': 1},
        ]
        issues = [
            {'region': 2, 'edge': 1, 'reason': 'absent neighbor', 'wall_record': 4, 'sector': 2},
            {'region': 9, 'edge': 0, 'reason': 'absent neighbor'},
        ]
        placements = [
            {'index': 1, 'template': 10, 'x': 1, 'y': 2, 'height': 3, 'heading': 4},
            {'index': 0, 'template': 11, 'x': 0, 'y': 0, 'height': 0, 'heading': 0},
        ]
        state_faces = [{
            'kind': 'movable', 'placement': 1, 'child': 8, 'child_mask': 2, 'mask': 2,
            'hidden': True, 'initial_visible': False,
        }]
        state_sprites = [{
            'placement': 1, 'child': 25, 'child_mask': 4, 'hidden': True,
        }]
        return regions, arrivals, faces, issues, placements, state_faces, state_sprites

    def test_components_bounds_states_and_unbound_labels(self):
        regions, arrivals, faces, issues, placements, state_faces, sprites = self._fixture()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_area(root, 'L_TEST', regions, arrivals, faces, issues, placements, state_faces, sprites)
            summary = inventory.write_inventory(root)
            area = json.loads((root / 'L_TEST' / 'review_inventory.json').read_text(encoding='utf-8'))
            self.assertEqual([component['region_ids'] for component in area['topology']['components']], [[0, 2], [5]])
            self.assertEqual(area['topology']['components'][0]['none_neighbor_slots'], 7)
            self.assertNotIn(None, area['topology']['components'][0]['region_ids'])
            self.assertEqual(area['nonprimary_regions'], [{'id': 9, 'record_role': 'floor_subdivision', 'owner': 0}])
            self.assertEqual(area['topology']['components'][0]['arrival_ids'], [3])
            self.assertEqual(area['topology']['components'][0]['arrivals_by_region'], {'0': [3]})
            self.assertEqual(
                [row['index'] for row in area['unassigned']['arrivals']],
                [1, 4, 8],
            )
            self.assertEqual(area['unassigned']['arrivals'][0]['region'], 9)
            self.assertIsNone(area['unassigned']['arrivals'][1]['region'])
            joined = area['topology']['components'][0]
            self.assertEqual(joined['emitted_faces'], {'floor': 1, 'ceiling': 1, 'wall': 1})
            self.assertEqual(area['topology']['components'][1]['emitted_faces']['wall'], 1)
            self.assertEqual(joined['geometry_issues_by_region']['2'][0]['reason'], 'absent neighbor')
            self.assertEqual(joined['bounds']['world']['min'][0], 0.0)
            self.assertEqual(joined['bounds']['world']['max'][0], 1.0)
            self.assertEqual(joined['bounds']['world']['min'][2], 0.0)
            self.assertEqual(joined['bounds']['world']['max'][2], 2.0)
            self.assertEqual(joined['bounds']['world']['min'][1], -10)
            self.assertEqual(area['adjacent_labels']['binding'], 'UNBOUND')
            self.assertFalse(area['adjacent_labels']['assigned_to_components'])
            self.assertNotIn('name', joined)
            self.assertNotIn('adjacent_labels', joined)
            self.assertFalse(area['ready_for_content'])
            self.assertEqual(area['visual_qa'], 'pending')
            self.assertEqual(joined['visual_qa'], 'pending')
            self.assertFalse(joined['ready_for_content'])
            self.assertEqual(area['source']['sha256'], 'abc')
            self.assertEqual(area['source']['geometry_sha256'], 'def')
            self.assertEqual([row['index'] for row in area['mechanisms']['placements']], [0, 1])
            self.assertEqual(area['mechanisms']['initial_faces_by_provenance'], [
                {'placement': 1, 'child': 7, 'mask': 1, 'faces': 2},
            ])
            self.assertEqual(area['mechanisms']['later_state_faces_by_provenance'], [
                {'placement': 1, 'child': 8, 'mask': 2, 'faces': 1},
            ])
            self.assertEqual(area['mechanisms']['later_state_sprites_by_provenance'], [
                {'placement': 1, 'child': 25, 'mask': 4, 'sprites': 1},
            ])
            self.assertIsNone(area['mechanisms']['states_all_reachable'])
            self.assertFalse(area['mechanisms']['mechanism_function_claimed'])
            self.assertTrue(all('unused' not in component for component in area['topology']['components']))
            self.assertFalse(summary['ready_for_content'])
            self.assertIn('UNBOUND', (root / 'review_inventory.md').read_text(encoding='utf-8'))
            again = inventory.build_area(root / 'L_TEST')
            self.assertEqual(again, area)

    def test_duplicate_region_id_fails(self):
        regions = [
            _region(1, 'primary_region', [None]),
            _region(1, 'primary_region', [None]),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            area = _write_area(Path(tmp), 'DUP', regions)
            with self.assertRaises(inventory.InventoryError):
                inventory.build_area(area)

    def test_mismatched_source_and_empty_export_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(inventory.InventoryError):
                inventory.write_inventory(root)
            area = _write_area(root, 'MISMATCH', [_region(1, 'primary_region', [None])])
            path = area / 'review.json'
            review = json.loads(path.read_text())
            review['source'] = {'sha256': 'another archive'}
            path.write_text(json.dumps(review))
            with self.assertRaises(inventory.InventoryError):
                inventory.build_area(area)

    def test_malformed_neighbor_fails_and_none_is_kept(self):
        missing = [_region(1, 'primary_region', [99, None])]
        with tempfile.TemporaryDirectory() as tmp:
            area = _write_area(Path(tmp), 'BAD', missing)
            with self.assertRaises(inventory.InventoryError):
                inventory.build_area(area)
        typed = [_region(1, 'primary_region', ['east'])]
        with tempfile.TemporaryDirectory() as tmp:
            area = _write_area(Path(tmp), 'BAD', typed)
            with self.assertRaises(inventory.InventoryError):
                inventory.build_area(area)
        none_only = [_region(4, 'primary_region', [None, None])]
        with tempfile.TemporaryDirectory() as tmp:
            area = _write_area(Path(tmp), 'EDGE', none_only)
            built = inventory.build_area(area)
            self.assertEqual(built['topology']['components'][0]['none_neighbor_slots'], 2)
            self.assertEqual(built['topology']['components'][0]['region_ids'], [4])

    def test_child_only_neighbor_does_not_join_primary(self):
        regions = [
            _region(3, 'primary_region', [None]),
            _region(8, 'floor_subdivision', [3], owner=3),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            area = _write_area(Path(tmp), 'CHILD', regions)
            built = inventory.build_area(area)
            self.assertEqual(built['topology']['components'][0]['region_ids'], [3])
            self.assertEqual(built['nonprimary_regions'][0]['id'], 8)


if __name__ == '__main__':
    unittest.main()
