#!/usr/bin/env python3
"""G-11: run a regression suite as N parallel shards, each in its own detached worktree, and merge the reports.

  python3 tools/run_sharded_sweep.py --out DIR [--shards 4] [--suite all] [--durations REPORT.json]
        [--shard-root ~/opus_work/shards] [--timeout 1500] [--test NAME ...]

Each shard worktree (SHARD_ROOT/lol2_shard_<i>) is checked out detached at this project's HEAD and staged from this
project with tools/prepare_lane_worktree.py, so every shard has its own res://tmp, its own XDG user data (slots,
autosave, user://tests) and its own private Xvfb per rendered run. Shards are cut along producer-to-reader chains
(tools/regression_shards.py) and keep registry order. Caps: at most N (<= 6) sweep Godot at once (one per shard), and
every launch goes through tmp/godot_dummy.sh, which waits for --min-free-gib (default 10) GiB free; Dummy audio.

DIR receives shard_<i>/ (each shard's own report.json and logs), report.json (merged), chains.json (every file shared
by two or more tests, with the tests; the debt list) and cross_shard.json (tests whose chain partner ran in another
shard; must be empty, else the run fails). Uncommitted changes in this project are not in the shards: commit first.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import run_regressions  # noqa: E402
from regression_shards import split, durations_from  # noqa: E402
from prepare_lane_worktree import GATE_ENV, geometry_move_problems  # noqa: E402


def git(*args, cwd=ROOT):
    return subprocess.run(['git', *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def staged_ok(path):
    """True if the shard's staged inputs still match their manifest (tools/stage_worktree.py --check)."""
    return subprocess.run([sys.executable, str(path / 'tools/stage_worktree.py'), '--check', str(path)],
                          capture_output=True, text=True).returncode == 0


def prepare_shard(path, head, shard_root):
    if (path / '.git').exists():
        git('checkout', '--detach', '--quiet', head, cwd=path)
        # Tests rewrite chain saves under tmp/, so a reused shard can hold changed inputs; its count would be void
        # (sweep 6d31407b, 2026-11-14: ~20 'Untouched ... pin' stops). Such a shard is rebuilt from scratch - only
        # this tool's own SHARD_ROOT/lol2_shard_<i> worktrees, never with a live gate in them; anything else refuses.
        if (path / 'tmp/staged_inputs/manifest.json').is_file() and not staged_ok(path):
            from regression_source import gate_marker
            if path.parent.resolve() != shard_root.resolve() or not path.name.startswith('lol2_shard_'):
                raise SystemExit(f'FAIL: {path} has changed staged inputs and is not a sweep shard; restage it by hand')
            if gate_marker(path) is not None:
                raise SystemExit(f'FAIL: {path} has changed staged inputs and a live gate; not touching it')
            print(f'  {path.name}: staged inputs changed by an earlier run; rebuilding the shard', flush=True)
            git('worktree', 'remove', '--force', str(path))
    if not (path / '.git').exists():
        git('worktree', 'add', '--detach', str(path), head)
    # A shard whose inputs still match keeps them; only the wrapper is refreshed (restaging reads the donor).
    staged = (path / 'tmp/staged_inputs/manifest.json').is_file()
    mode = ['--wrapper-only'] if staged else ['--from', str(ROOT)]
    subprocess.run([sys.executable, str(ROOT / 'tools/prepare_lane_worktree.py'), str(path), *mode],
                   check=not staged, stdout=subprocess.DEVNULL)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--shards', type=int, default=4)
    parser.add_argument('--suite', default='all', choices=run_regressions.SUITES)
    parser.add_argument('--durations')
    parser.add_argument('--shard-root', type=Path, default=Path('~/opus_work/shards'))
    parser.add_argument('--timeout', default='1500')
    parser.add_argument('--test', action='append', default=[])
    parser.add_argument('--min-free-gib', default='10', help='every Godot launch waits for this much MemAvailable (12 while the owner plays)')
    args = parser.parse_args()
    if not 1 <= args.shards <= 6:
        parser.error('--shards must be 1..6 (lead cap 2026-11-12: at most 6 sweep Godot)')
    if git('status', '--porcelain', '--untracked-files=no'):
        print('WARNING: uncommitted changes in this project are not part of the shards', flush=True)
    head = git('rev-parse', 'HEAD')
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    tests = run_regressions.SUITES[args.suite]
    if args.test:
        tests = [(n, m) for n, m in tests if n in args.test]
    durations = durations_from(args.durations) if args.durations else None
    plan, group_of, shared = split(tests, args.shards, durations, ROOT)
    (out / 'chains.json').write_text(json.dumps({'head': head, 'shared_paths': shared}, indent=1) + '\n')
    shard_of = {name: i for i, shard in enumerate(plan) for name, _ in shard}
    cross = {path: sorted({shard_of[n] + 1 for n in names if n in shard_of})
             for path, names in shared.items() if len({shard_of[n] for n in names if n in shard_of}) > 1}
    (out / 'cross_shard.json').write_text(json.dumps(cross, indent=1) + '\n')
    if cross:
        print(f'FAIL: {len(cross)} shared files are split across shards: {sorted(cross)[:5]}')
        return 2
    env = {**os.environ, **{k: v for k, v in GATE_ENV.items() if k not in os.environ}, 'LOL2_MIN_FREE_GIB': str(args.min_free_gib)}
    processes = []
    started = time.time()
    # Prepare and check every shard before any Godot starts: a stale geometry-move pack makes the game load the original
    # map, so the whole sweep would test the wrong map (void sweep 6d31407, 2026-11-14). Refuse instead.
    stale = []
    for i, shard in enumerate(plan):
        if not shard:
            continue
        path = args.shard_root / f'lol2_shard_{i + 1}'
        path.parent.mkdir(parents=True, exist_ok=True)
        print(f'shard {i + 1}: preparing {path} at {head[:7]} ({len(shard)} tests)', flush=True)
        prepare_shard(path, head, args.shard_root)
        stale += [f'shard {i + 1}: {line}' for line in geometry_move_problems(path)[0]]
    if stale:
        print('FAIL: refusing to start the sweep:\n  ' + '\n  '.join(stale), flush=True)
        return 2
    for i, shard in enumerate(plan):
        if not shard:
            continue
        path = args.shard_root / f'lol2_shard_{i + 1}'
        command = [sys.executable, 'tools/run_regressions.py', '--suite', args.suite, '--godot', 'tmp/godot_dummy.sh',
                   '--timeout', args.timeout, '--out', str(out / f'shard_{i + 1}')]
        for name, _ in shard:
            command += ['--test', name]
        log = open(out / f'shard_{i + 1}.log', 'w')
        processes.append((i + 1, subprocess.Popen(command, cwd=path, env=env, stdout=log, stderr=subprocess.STDOUT), log))
        time.sleep(5)  # stagger the first launches
    for index, process, log in processes:
        process.wait()
        log.close()
        print(f'shard {index}: exit {process.returncode}', flush=True)
    merged = {'suite': args.suite, 'head': head, 'shards': args.shards, 'seconds': round(time.time() - started, 1),
              'tests': [], 'shard_reports': {}}
    for index, _, _ in processes:
        report_path = out / f'shard_{index}' / 'report.json'
        report = json.loads(report_path.read_text()) if report_path.is_file() else {}
        merged['shard_reports'][index] = {'complete': report.get('complete', False), 'tests': len(report.get('tests', [])),
                                          'source_stable': report.get('source_stable')}
        for row in report.get('tests', []):
            merged['tests'].append({**row, 'shard': index})
    order = {name: i for i, (name, _) in enumerate(tests)}
    merged['tests'].sort(key=lambda row: order.get(row['name'], 1 << 30))
    ran = {row['name'] for row in merged['tests']}
    merged['missing'] = [name for name, _ in tests if name not in ran]
    merged['passed_count'] = sum(1 for row in merged['tests'] if row['passed'])
    merged['failed'] = [row['name'] for row in merged['tests'] if not row['passed'] and not row.get('skipped')]
    merged['skipped'] = [row['name'] for row in merged['tests'] if row.get('skipped')]
    merged['complete'] = all(r['complete'] for r in merged['shard_reports'].values()) and not merged['missing']
    merged['passed'] = merged['complete'] and not merged['failed']
    (out / 'report.json').write_text(json.dumps(merged, indent=2) + '\n')
    print(f"{merged['passed_count']}/{len(tests)} passed, {len(merged['failed'])} failed, {len(merged['skipped'])} skipped,"
          f" {len(merged['missing'])} missing, {merged['seconds'] / 60:.1f} min. Report: {out / 'report.json'}")
    return 0 if merged['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
