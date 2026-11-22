#!/usr/bin/env python3
"""Adversarial search cases: supplies, reuse, identity and incomplete evidence."""
from pathlib import Path
import tempfile
import unittest

from quest_resource_model import Rule, explore, reserve_frontier, source_errors


def rule(name, requires=(), adds=(), removes=(), forbids=()):
    return Rule(name, frozenset(requires), frozenset(adds), frozenset(removes), frozenset(forbids))


class ResourceSearchTests(unittest.TestCase):
    def test_exact_identity_not_definition_and_shortest_loss(self):
        rules = [rule("offer", ["carried:exact68"], ["goal"], ["carried:exact68"]),
                 rule("eat", ["carried:exact68"], ["spent:exact68"], ["carried:exact68"]),
                 rule("harvest_other_aloe", [], ["carried:other109"])]
        result = explore(["carried:exact68"], rules, ["goal"])
        self.assertTrue(result["initial_goal_reachable"])
        self.assertEqual(result["witnesses"][0]["actions"], ["eat"])
        self.assertEqual(result["whole_game_verdict"], "UNKNOWN")

    def test_future_supply_recovers_loss(self):
        rules = [rule("offer", ["item"], ["goal"], ["item"]),
                 rule("eat", ["item"], [], ["item"]),
                 rule("open_future_room", [], ["room"]),
                 rule("replacement", ["room"], ["item"])]
        self.assertEqual(explore(["item"], rules, ["goal"])["witnesses"], [])

    def test_future_supply_locked_by_consumed_item_does_not_rescue(self):
        rules = [rule("offer", ["item"], ["goal"], ["item"]),
                 rule("eat", ["item"], [], ["item"]),
                 rule("open_room", ["goal"], ["room"]),
                 rule("replacement", ["room"], ["item"])]
        self.assertEqual(explore(["item"], rules, ["goal"])["witnesses"][0]["actions"], ["eat"])

    def test_retrievable_occupation_and_repeated_use_not_loss(self):
        rules = [rule("place", ["carried"], ["occupied"], ["carried"]),
                 rule("retrieve", ["occupied"], ["carried"], ["occupied"]),
                 rule("finish", ["carried"], ["goal"])]
        self.assertEqual(explore(["carried"], rules, ["goal"])["status"], "NO_LOSS_IN_MODEL")

    def test_spent_finite_source_cannot_respawn(self):
        rules = [rule("collect", [], ["item", "collected"], forbids=["collected"]),
                 rule("eat", ["item"], ["spent"], ["item"]),
                 rule("offer", ["item"], ["goal"], ["item"])]
        result = explore([], rules, ["goal"])
        self.assertEqual(result["witnesses"][0]["actions"], ["collect", "eat"])

    def test_bound_and_unknown_producers_never_certify_softlock(self):
        result = explore([], [rule("a", [], ["a"]), rule("b", ["a"], ["b"])], ["b"], max_states=1)
        self.assertEqual(result["status"], "UNKNOWN_STATE_BOUND")
        self.assertEqual(result["witnesses"], [])
        result = explore([], [], ["missing"], unresolved=["unhosted native grant"])
        self.assertEqual(result["whole_game_verdict"], "UNKNOWN")
        self.assertFalse(result["initial_goal_reachable"])

    def test_missing_changed_source_and_path_escape_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            Path(folder, "writer.gd").write_text("changed")
            self.assertEqual(len(source_errors(folder, {"gone.gd": "0" * 64,
                                                       "writer.gd": "0" * 64,
                                                       "../outside": "0" * 64})), 3)
            self.assertTrue(source_errors(folder, {}))

    def test_duplicate_rule_names_refused(self):
        with self.assertRaises(ValueError):
            explore([], [rule("same"), rule("same")], ["goal"])

    def test_two_unfinished_slots_need_two_copies_then_release(self):
        rules = [rule("first_a", ["a"], ["first"], ["a"]),
                 rule("first_b", ["b"], ["first"], ["b"]),
                 rule("second_a", ["a"], ["second"], ["a"]),
                 rule("second_b", ["b"], ["second"], ["b"])]
        groups = {"a": "crystal", "b": "crystal"}
        out = reserve_frontier(["a", "b"], rules, ["first", "second"], groups)
        self.assertEqual(out["alternatives"],
                         [{"held": ["a", "b"], "counts": {"crystal": 2}}])
        out = reserve_frontier(["first", "b"], rules, ["first", "second"],
                               {"b": "crystal"})
        self.assertEqual(out["alternatives"][0]["counts"], {"crystal": 1})
        out = reserve_frontier(["first", "second", "b"], rules,
                               ["first", "second"], {"b": "crystal"})
        self.assertEqual(out["alternatives"], [{"held": [], "counts": {}}])

    def test_alternative_ending_is_not_three_independent_reserves(self):
        rules = [rule("finish_with_" + item, [item], ["ending"])
                 for item in ["bow", "sword", "horn"]]
        groups = {item: "final_weapon" for item in ["bow", "sword", "horn"]}
        out = reserve_frontier(groups, rules, ["ending"], groups)
        self.assertEqual([a["held"] for a in out["alternatives"]],
                         [["bow"], ["horn"], ["sword"]])
        self.assertTrue(all(a["counts"] == {"final_weapon": 1}
                            for a in out["alternatives"]))

    def test_future_exact_requirement_precedes_alternative_ending(self):
        rules = [rule("armory_fire", ["blue_bow"], ["armory_done"])]
        rules += [rule("finish_with_" + item, ["armory_done", item], ["ending"])
                  for item in ["blue_bow", "dark_sword", "horn"]]
        groups = {item: "weapon" for item in ["blue_bow", "dark_sword", "horn"]}
        out = reserve_frontier(groups, rules, ["ending"], groups)
        self.assertEqual(out["alternatives"],
                         [{"held": ["blue_bow"], "counts": {"weapon": 1}}])
        out = reserve_frontier([*groups, "armory_done"], rules, ["ending"], groups)
        self.assertEqual([a["held"] for a in out["alternatives"]],
                         [["blue_bow"], ["dark_sword"], ["horn"]])

    def test_definition_spare_cannot_replace_exact_ingredient(self):
        out = reserve_frontier(["exact68", "other_aloe"],
                               [rule("offer", ["exact68"], ["goal"], ["exact68"])],
                               ["goal"], {"exact68": "aloe", "other_aloe": "aloe"})
        self.assertEqual(out["alternatives"],
                         [{"held": ["exact68"], "counts": {"aloe": 1}}])

    def test_future_accessible_supply_and_retrieval_are_not_reserved_twice(self):
        rules = [rule("take", ["world"], ["leaf"], ["world"]),
                 rule("offer", ["leaf"], ["goal"], ["leaf"])]
        out = reserve_frontier(["world", "spare"], rules, ["goal"],
                               {"spare": "leaf"})
        self.assertEqual(out["alternatives"], [{"held": [], "counts": {}}])
        rules = [rule("retrieve", ["occupied"], ["stone"], ["occupied"]),
                 rule("finish", ["stone"], ["goal"])]
        out = reserve_frontier(["occupied"], rules, ["goal"], {})
        self.assertEqual(out["alternatives"], [{"held": [], "counts": {}}])

    def test_unreachable_incomplete_or_nonmonotone_never_means_reserve_zero(self):
        out = reserve_frontier(["other"], [], ["goal"], {"other": "aloe"})
        self.assertEqual(out["status"], "UNKNOWN_INITIAL_GOAL_UNREACHABLE")
        self.assertEqual(out["alternatives"], [])
        rules = [rule("empty_hands", [], ["goal"], forbids=["item"])]
        out = reserve_frontier(["item"], rules, ["goal"], {"item": "item"})
        self.assertEqual(out["status"], "UNKNOWN_NONMONOTONE_RESOURCES")
        out = reserve_frontier(["a", "b"], [], ["goal"],
                               {"a": "item", "b": "item"}, max_subsets=2)
        self.assertEqual(out["status"], "UNKNOWN_SUBSET_BOUND")
        out = reserve_frontier([], [rule("a", [], ["a"]),
                                   rule("b", ["a"], ["goal"])], ["goal"], {},
                               max_states=1)
        self.assertEqual(out["status"], "UNKNOWN_STATE_BOUND")
        self.assertEqual(out["alternatives"], [])


if __name__ == "__main__":
    unittest.main()
