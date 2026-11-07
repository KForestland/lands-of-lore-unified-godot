#!/usr/bin/env python3
"""W4 test registry consistency (2026-10-31).

Every tests/registry/<name>.json must load (tools/run_regressions.py refuses a bad suite/mode, a name that is not the file
name, a missing tests/<name>.gd or a negative order (W16: equal orders allowed)). Every tests/*.gd that is a SceneTree test must either hold a registry
file or stand in tests/registry/_unregistered.txt, the snapshot of the tests that were not in any suite when the registry
was made (membership unchanged by W4). A new SceneTree test that registers nowhere fails this check. Exit 1 on any gap."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))


def main():
    import run_regressions as rr  # import = the loader's own validation
    registered = {p.stem for p in rr.REGISTRY.glob('*.json')}
    known_unregistered = {l.strip() for l in (rr.REGISTRY / '_unregistered.txt').read_text().splitlines()
                          if l.strip() and not l.startswith('#')}
    problems = []
    for gd in sorted((ROOT / 'tests').glob('*.gd')):
        text = gd.read_text(errors='replace')
        # A test is a SceneTree script or one that extends another test script (the earned-walk chain tests).
        if not re.search(r'^extends SceneTree', text, re.M) and not re.search(r'^extends "res://tests/', text, re.M):
            continue
        if gd.stem not in registered and gd.stem not in known_unregistered:
            problems.append(f'{gd.name}: SceneTree test with no tests/registry/{gd.stem}.json and not in _unregistered.txt')
    for name in sorted(registered & known_unregistered):
        problems.append(f'{name}: both registered and listed in _unregistered.txt')
    for name in sorted(known_unregistered):
        if not (ROOT / 'tests' / f'{name}.gd').exists():
            problems.append(f'_unregistered.txt names tests/{name}.gd, which does not exist')
    for suite in ('portable', 'core', 'hive'):
        entries = [json.loads(p.read_text()) for p in rr.REGISTRY.glob('*.json')]
        orders = [int(e['order']) for e in entries if e['suite'] == suite]
        if any(o < 0 for o in orders):  # W16: equal orders allowed (ties run in name order); only negatives are wrong
            problems.append(f'suite {suite}: negative order values')
    for line in problems:
        print('FAIL ' + line)
    if problems:
        return 1
    print('PASS registry: %d registered (portable %d, core %d, hive %d, all %d), %d known unregistered SceneTree tests' % (
        len(registered), len(rr.SUITES['portable']), len(rr.SUITES['core']), len(rr.SUITES['hive']), len(rr.SUITES['all']),
        len(known_unregistered)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
