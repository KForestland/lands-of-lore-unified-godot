#!/usr/bin/env python3
"""Finite resource search, not a claim about uncensused game routes.

Atoms name exact resource identities/locations and story facts. Definitions are
metadata, never interchangeable identities. Each rule is one legal modeled use,
trade, pickup or retrieval. A loss witness must start in a state from which the
goal is reachable and cross into one from which it is not. All results remain
model-only until runtime and supply/route coverage are independently qualified.
"""
from collections import defaultdict, deque
from dataclasses import dataclass
import hashlib
from itertools import combinations
from pathlib import Path


@dataclass(frozen=True)
class Rule:
    name: str
    requires: frozenset[str]
    adds: frozenset[str]
    removes: frozenset[str] = frozenset()
    forbids: frozenset[str] = frozenset()

    def apply(self, state):
        if not self.requires <= state or self.forbids & state:
            return None
        next_state = (state - self.removes) | self.adds
        return next_state if next_state != state else None


def source_errors(root, pins):
    errors = []
    root = Path(root).resolve()
    if not pins:
        return ["No source evidence pinned."]
    for relative, expected in pins.items():
        path = (root / relative).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            errors.append(f"Missing/outside source: {relative}")
        elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            errors.append(f"Changed source: {relative}")
    return errors


def explore(initial, rules, goal, *, max_states=100000, unresolved=()):
    """Exhaust the finite graph, then compute backwards goal reachability.

    A bounded/interrupted search cannot certify a losing state. We return no
    witnesses if the state limit is exceeded, even if some branches look lost.
    BFS parent paths make each returned boundary witness shortest to its state.
    """
    initial, goal = frozenset(initial), frozenset(goal)
    if not goal or max_states < 1:
        raise ValueError("Nonempty goal and positive state bound required")
    if len({rule.name for rule in rules}) != len(rules):
        raise ValueError("Rule names must be unique")
    pending = deque([initial])
    parents = {initial: None}
    reverse = defaultdict(set)
    edges = []
    while pending:
        state = pending.popleft()
        for rule in rules:
            target = rule.apply(state)
            if target is None:
                continue
            edges.append((state, rule.name, target))
            reverse[target].add(state)
            if target not in parents:
                if len(parents) >= max_states:
                    return {"status": "UNKNOWN_STATE_BOUND", "states": len(parents),
                            "model_only": True, "witnesses": [],
                            "unresolved": list(unresolved)}
                parents[target] = (state, rule.name)
                pending.append(target)
    winning = {state for state in parents if goal <= state}
    pending = deque(winning)
    while pending:
        for predecessor in reverse[pending.popleft()]:
            if predecessor not in winning:
                winning.add(predecessor)
                pending.append(predecessor)

    def path_to(state):
        actions = []
        while parents[state] is not None:
            state, action = parents[state]
            actions.append(action)
        return list(reversed(actions))

    witnesses = []
    seen = set()
    for source, action, target in edges:
        if source in winning and target not in winning and target not in seen:
            seen.add(target)
            witnesses.append({"actions": path_to(source) + [action],
                              "lost_atoms": sorted(source - target),
                              "state": sorted(target)})
    witnesses.sort(key=lambda row: (len(row["actions"]), row["actions"]))
    return {"status": "MODEL_LOSS_FOUND" if witnesses else (
                "MODEL_INITIAL_GOAL_UNREACHABLE" if initial not in winning else
                "NO_LOSS_IN_MODEL"),
            "model_only": True, "states": len(parents), "edges": len(edges),
            "initial_goal_reachable": initial in winning,
            "whole_game_verdict": "UNKNOWN", "unresolved": list(unresolved),
            "witnesses": witnesses}


def reserve_frontier(initial, rules, goal, carried_groups, *, max_subsets=4096,
                     max_states=100000, unresolved=()):
    """Model-only minimal sets of carried resources that preserve a goal.

    Keys of carried_groups are *exact held atoms* already in initial; values
    are display groups. Story, collected/source, occupied and spent atoms stay
    intact. This is a counterfactual supply query, NOT a legal-use witness:
    actual losses must still be explored using their complete Rule effects.

    Return exact identity alternatives, not one independent minimum per group:
    the bow OR sword OR horn goal must never become three reserves. Likewise a
    different Aloe identity cannot replace an exact ritual ingredient. Refuse
    negative held-resource preconditions: those need an exact-state policy,
    rather than an upward-closed minimum-count reserve. Inspect every subset.
    An unreachable initial goal or exhausted budget yields UNKNOWN, not zero.
    """
    initial = frozenset(initial)
    rules, goal = tuple(rules), frozenset(goal)
    resources = sorted(carried_groups)
    if not set(resources) <= initial:
        raise ValueError("Every candidate reserve must be an initially held atom")
    if max_subsets < 1:
        raise ValueError("Positive subset bound required")
    result = {"model_only": True, "whole_game_verdict": "UNKNOWN",
              "unresolved": list(unresolved), "alternatives": []}
    if 2 ** len(resources) > max_subsets:
        return {**result, "status": "UNKNOWN_SUBSET_BOUND"}
    if any(rule.forbids & set(resources) for rule in rules):
        return {**result, "status": "UNKNOWN_NONMONOTONE_RESOURCES"}
    baseline = explore(initial, rules, goal, max_states=max_states,
                       unresolved=unresolved)
    if baseline["status"] == "UNKNOWN_STATE_BOUND":
        return {**result, "status": "UNKNOWN_STATE_BOUND"}
    if not baseline["initial_goal_reachable"]:
        return {**result, "status": "UNKNOWN_INITIAL_GOAL_UNREACHABLE"}
    context = initial - set(resources)
    winning = []
    for size in range(len(resources) + 1):
        for group in combinations(resources, size):
            held = frozenset(group)
            answer = explore(context | held, rules, goal,
                             max_states=max_states, unresolved=unresolved)
            if answer["status"] == "UNKNOWN_STATE_BOUND":
                return {**result, "status": "UNKNOWN_STATE_BOUND"}
            if answer["initial_goal_reachable"]:
                winning.append(held)
    for held in winning:
        if any(other < held for other in winning):
            continue
        counts = defaultdict(int)
        for atom in held:
            counts[carried_groups[atom]] += 1
        result["alternatives"].append({"held": sorted(held),
                                       "counts": dict(sorted(counts.items()))})
    return {**result, "status": "MODEL_RESERVE_FRONTIER",
            "subsets_checked": 2 ** len(resources)}
