#!/usr/bin/env python3
"""Explored-atlas rules: visit, sight, old-save migration, and a finished area."""
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import atlas_explored


class ExploredTests(unittest.TestCase):
    def test_new_game_reveals_visit_and_sight(self):
        saved = atlas_explored.initial()
        self.assertEqual(atlas_explored.validate(saved, {}), "")
        nxt = atlas_explored.reveal(saved, "L14_HT", [4, 4, -1, 9])
        self.assertEqual(nxt["areas"]["L14_HT"], {"full": False, "regions": [4, 9]})
        self.assertEqual(atlas_explored.validate(nxt, {}), "")

    def test_old_save_marks_visited_areas_full(self):
        quests = {"act2_creatures_L8_SJ": {}, "act2_creatures_NOPE": {}, "l8_tree": {}}
        saved = atlas_explored.migrate(quests, "L14_HT")
        self.assertTrue(saved["areas"]["L14_HT"]["full"])
        self.assertTrue(saved["areas"]["L8_SJ"]["full"])
        self.assertNotIn("NOPE", saved["areas"])
        self.assertEqual(saved["areas"]["L14_HT"]["regions"], [])
        self.assertEqual(atlas_explored.validate(saved, quests), "")
        stayed = atlas_explored.reveal(saved, "L14_HT", [3])
        self.assertEqual(stayed["areas"]["L14_HT"]["regions"], [])
        self.assertTrue(stayed["areas"]["L14_HT"]["full"])

    def test_finished_area_collapses(self):
        saved = atlas_explored.reveal(atlas_explored.initial(), "L4_HJ", [0, 2, 1], 3)
        self.assertEqual(saved["areas"]["L4_HJ"], {"full": True, "regions": []})

    def test_area_of_and_rejects(self):
        self.assertEqual(atlas_explored.area_of({"area_id": "L16_CA", "geometry_file": "jungle.json"}), "L16_CA")
        self.assertEqual(atlas_explored.area_of({"geometry_file": "res://dark_halls/area.json"}), "L7_DH")
        self.assertEqual(atlas_explored.area_of({"geometry_file": "museum.json"}), "")
        bad = {"version": 1, "areas": {"L14_HT": {"full": False, "regions": [1, 1]}}}
        self.assertNotEqual(atlas_explored.validate(bad, {}), "")
        huge = {"version": 1, "areas": {"L14_HT": {"full": True, "regions": [1]}}}
        self.assertNotEqual(atlas_explored.validate(huge, {}), "")


if __name__ == "__main__":
    unittest.main()
