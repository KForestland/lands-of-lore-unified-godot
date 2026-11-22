#!/usr/bin/env python3
"""G-11: split a regression suite into N shards along producer-to-reader chains.

Two tests are chained when their sources (the test file and any res://tests/ script it preloads or loads) name the
same concrete file under res://tmp/ or user:// (a path at least two levels deep, so a bare "user://tests" or
"res://tmp" directory does not chain everything). Chained tests always land in the same shard, and every shard keeps
registry order, so a reader still runs after its writer exactly as in a serial sweep. Groups are packed onto shards
largest first by estimated seconds (from an earlier report.json when given, else one unit per test).

  python3 tools/regression_shards.py --suite all --shards 4 [--durations REPORT.json] [--chains OUT.json]
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH_RE = re.compile(r'(res://tmp/[A-Za-z0-9_./-]+|user://[A-Za-z0-9_./-]+)')
SCRIPT_RE = re.compile(r'res://tests/[A-Za-z0-9_./-]+\.gd')


def concrete(path):
    body = path.split('://', 1)[1].rstrip('/')
    return body.count('/') >= 1


def sources(name, root=ROOT, seen=None):
    seen = set() if seen is None else seen
    path = root / 'tests' / f'{name}.gd'
    texts = []
    stack = [path]
    while stack:
        current = stack.pop()
        if current in seen or not current.is_file():
            continue
        seen.add(current)
        text = current.read_text(errors='replace')
        texts.append(text)
        for script in SCRIPT_RE.findall(text):
            stack.append(root / script[len('res://'):])
    return '\n'.join(texts)


def chains(tests, root=ROOT):
    """Union-find over shared concrete paths. Returns (group id per test, {path: [tests]} for shared paths)."""
    parent = {name: name for name, _ in tests}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    users = {}
    for name, _ in tests:
        for path in set(PATH_RE.findall(sources(name, root))):
            path = path.rstrip('.')
            if concrete(path):
                users.setdefault(path, []).append(name)
    shared = {path: names for path, names in users.items() if len(names) > 1}
    for names in shared.values():
        for other in names[1:]:
            a, b = find(names[0]), find(other)
            if a != b:
                parent[b] = a
    return {name: find(name) for name, _ in tests}, shared


def split(tests, shards, durations=None, root=ROOT):
    """Returns (list of shards, each a registry-ordered list of (name, mode); group per test; shared paths)."""
    durations = durations or {}
    group_of, shared = chains(tests, root)
    groups = {}
    for name, _ in tests:
        groups.setdefault(group_of[name], []).append(name)
    weight = {g: sum(float(durations.get(n, 1.0)) for n in names) for g, names in groups.items()}
    load = [0.0] * shards
    shard_of_group = {}
    for g in sorted(groups, key=lambda g: (-weight[g], g)):
        target = min(range(shards), key=lambda i: (load[i], i))
        shard_of_group[g] = target
        load[target] += weight[g]
    out = [[] for _ in range(shards)]
    for name, mode in tests:  # registry order inside each shard
        out[shard_of_group[group_of[name]]].append((name, mode))
    return out, group_of, shared


def durations_from(report_path):
    data = json.loads(Path(report_path).read_text())
    return {row['name']: float(row.get('seconds', row.get('duration', 1.0)) or 1.0) for row in data.get('tests', [])}


def main():
    import sys
    sys.path.insert(0, str(ROOT / 'tools'))
    import run_regressions
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--suite', default='all', choices=run_regressions.SUITES)
    parser.add_argument('--shards', type=int, default=4)
    parser.add_argument('--durations')
    parser.add_argument('--chains', help='write the chain list (tests that share a file) to this JSON file')
    args = parser.parse_args()
    tests = run_regressions.SUITES[args.suite]
    plan, group_of, shared = split(tests, args.shards, durations_from(args.durations) if args.durations else None)
    for i, shard in enumerate(plan):
        print(f'shard {i + 1}/{args.shards}: {len(shard)} tests')
    if args.chains:
        Path(args.chains).write_text(json.dumps({'shared_paths': shared}, indent=1) + '\n')
        print(f'{len(shared)} shared paths written to {args.chains}')


if __name__ == '__main__':
    main()
