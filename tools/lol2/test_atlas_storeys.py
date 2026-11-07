#!/usr/bin/env python3
"""Storey grouping over a synthetic ramp and every in-repo creature-nav area."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import atlas_storeys

ROOT = Path(__file__).resolve().parents[2]
NAV = ROOT / "assets" / "lol2" / "generated" / "creature_nav"
BLOCKS = ROOT / "assets" / "lol2" / "generated" / "region_blockers"
QUAD = [[0, 0], [1, 0], [1, 1], [0, 1]]


def storey_map(payload):
    return {row["region"]: row for row in payload["regions"]}


class StoreyTests(unittest.TestCase):
    def test_ramp_stays_one_storey(self):
        regions = [
            [QUAD, 0, 0, [[1, 0, 0]]],
            [QUAD, 10, 10, [[0, 0, 0], [2, 0, 0]]],
            [QUAD, 20, 20, [[1, 0, 0]]],
            [QUAD, 200, 200, []],
            [[], 0, 0, []],
            [QUAD, 5, 5, [[6, 0, 0]]],
            [QUAD, 5, 5, [[5, 0, 0]]],
            [QUAD, 0, 0, []],
        ]
        rows, storeys = atlas_storeys.group_regions(regions, [5])
        by_id = {row["region"]: row for row in rows}
        self.assertEqual(by_id[0]["storey"], by_id[1]["storey"])
        self.assertEqual(by_id[1]["storey"], by_id[2]["storey"])
        self.assertNotEqual(by_id[0]["storey"], by_id[3]["storey"])
        self.assertNotEqual(by_id[0]["storey"], by_id[7]["storey"])
        self.assertEqual(by_id[3]["kind"], "isolated")
        self.assertEqual(by_id[4]["kind"], "unmapped")
        self.assertEqual(by_id[4]["storey"], -1)
        self.assertEqual(by_id[5]["kind"], "blocked")
        self.assertEqual(by_id[5]["storey"], by_id[6]["storey"])
        self.assertEqual(by_id[6]["kind"], "linked")
        self.assertEqual(by_id[7]["kind"], "isolated")
        self.assertEqual(sum(row["region_count"] for row in storeys) + 1, len(regions))
        self.assertLess(by_id[0]["storey"], by_id[3]["storey"])

    def test_every_nav_area(self):
        self.assertTrue(NAV.is_dir(), "creature_nav is in the repo")
        areas = sorted(path.stem for path in NAV.glob("*.json"))
        self.assertGreaterEqual(len(areas), 14)
        blocked_only = sorted(path.stem for path in BLOCKS.glob("*.json"))
        skipped = sorted(set(blocked_only) - set(areas))
        self.assertIn("L7_DH", skipped)
        with tempfile.TemporaryDirectory() as tmp:
            for area in areas:
                payload = atlas_storeys.build_area(NAV / ("%s.json" % area), BLOCKS)
                self.assertEqual(payload["area"], area)
                self.assertEqual(payload["step"], 32)
                self.assertNotIn("renderer", payload)
                rows = storey_map(payload)
                source = json.loads((NAV / ("%s.json" % area)).read_text())
                blocked = set(atlas_storeys.load_blocked(BLOCKS / ("%s.json" % area)))
                self.assertEqual(len(rows), len(source["regions"]))
                for index, region in enumerate(source["regions"]):
                    row = rows[index]
                    polygon, floor, _corner, edges = region
                    if len(polygon) == 0:
                        self.assertEqual(row["kind"], "unmapped")
                        self.assertEqual(row["storey"], -1)
                        continue
                    if index in blocked:
                        self.assertEqual(row["kind"], "blocked")
                    elif len(edges) > 0:
                        self.assertEqual(row["kind"], "linked")
                    else:
                        self.assertEqual(row["kind"], "isolated")
                    self.assertGreaterEqual(row["storey"], 0)
                    for edge in edges:
                        other = int(edge[0])
                        if other < 0 or other >= len(source["regions"]):
                            continue
                        if len(source["regions"][other][0]) == 0:
                            continue
                        if abs(float(floor) - float(source["regions"][other][1])) > 32:
                            continue
                        self.assertEqual(row["storey"], rows[other]["storey"])
                out = atlas_storeys.write_area(NAV / ("%s.json" % area), BLOCKS, tmp)
                written = json.loads(out.read_text())
                self.assertEqual(written["area"], area)
                self.assertEqual(len(written["regions"]), len(rows))


if __name__ == "__main__":
    unittest.main()
