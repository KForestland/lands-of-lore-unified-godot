#!/usr/bin/env python3
"""Run named verification profiles, or inspect an existing run without starting tests."""
import argparse
import datetime as dt
import json
import math
from pathlib import Path
import subprocess
import sys
from regression_source import snapshot, changes
from run_regressions import SUITES

ROOT = Path(__file__).resolve().parents[1]
PROFILES = {
    'quick': ['hive_attack_portable_test', 'player_continuity_contract_test'],
    'diagnostics': ['dev_diagnostics_test', 'dev_diagnostics_hosts_test'],
    'continuity': ['player_continuity_contract_test', 'player_continuity_chain_test',
                   'player_continuity_restart_test', 'cave_museum_transfer_test', 'hive_route_test'],
    'all': None,
}

def write(path, value):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.replace(path)

def assess(report, expected):
    errors = []
    if not report.get('complete'): errors.append('Regression report is incomplete')
    if report.get('passed') is not True: errors.append('One or more regressions failed')
    if report.get('source_stable') is not True: errors.append('Tested source was not stable')
    rows = report.get('tests', [])
    if [row.get('name') for row in rows] != expected: errors.append('Executed test list differs from selected profile')
    if not rows or any(row.get('passed') is not True for row in rows): errors.append('Missing or failed individual test results')
    if not report.get('source_start') or not report.get('source_end'): errors.append('Missing source snapshots')
    elif changes(report['source_start'], report['source_end']): errors.append('Source snapshots differ')
    return errors

def status(folder):
    summary = json.loads((folder / 'verification.json').read_text())
    report_path = folder / 'regressions/report.json'
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    rows = report.get('tests', [])
    print(f"{summary['profile']}: {summary['status']} | {sum(r.get('passed') is True for r in rows)}/{len(summary['selected_tests'])} passed")
    current = report.get('current_test')
    if current:
        started = dt.datetime.fromisoformat(current['started_utc'])
        elapsed = max(0, (dt.datetime.now(dt.timezone.utc) - started).total_seconds())
        print(f"Active at last update: {current['name']} | elapsed {elapsed:.0f}s | limit {current['timeout_seconds']}s")
        print('Live log:', report_path.parent / current['log'])
    for row in rows:
        if row.get('passed') is not True: print('FAILED:', row['name'], report_path.parent / row['log'])
    for error in summary.get('errors', []): print('ERROR:', error)
    if summary['status'] == 'running': print('Recorded state only; this is not a process-liveness check.')
    return 0

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=PROFILES, default='quick')
    parser.add_argument('--out', type=Path, help='Fresh output directory; existing directories are refused')
    parser.add_argument('--status', type=Path, help='Read status of an existing output directory; never runs tests')
    parser.add_argument('--timeout', type=float, default=300)
    parser.add_argument('--list', action='store_true', help='Show profile tests without running')
    args = parser.parse_args(argv)
    if args.status:
        try: return status(args.status.resolve())
        except (OSError, ValueError, KeyError) as error: parser.error(str(error))
    if not math.isfinite(args.timeout) or args.timeout <= 0: parser.error('timeout must be finite and positive')
    selected = PROFILES[args.profile]
    expected = [name for name, _ in SUITES['all'] if selected is None or name in selected]
    if selected is not None and set(expected) != set(selected): parser.error('Profile references unavailable tests')
    if args.list:
        print('\n'.join(expected)); return 0
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    folder = (args.out or ROOT / 'tmp/verification' / stamp).resolve()
    try: folder.mkdir(parents=True, exist_ok=False)
    except FileExistsError: parser.error('Output already exists; choose a fresh directory or use --status')
    report_path = folder / 'verification.json'
    before = snapshot(ROOT)
    summary = {'profile': args.profile, 'status': 'running', 'selected_tests': expected,
               'started_utc': stamp, 'errors': [], 'scope': 'Selected source regressions only; not a campaign, export or release qualification.'}
    write(report_path, summary)
    command = [sys.executable, str(ROOT / 'tools/run_regressions.py'), '--suite', 'all',
               '--out', str(folder / 'regressions'), '--timeout', str(args.timeout)]
    for name in selected or []: command += ['--test', name]
    try:
        result = subprocess.run(command, cwd=ROOT)
        summary['returncode'] = result.returncode
        if result.returncode != 0: summary['errors'].append(f'Runner exited with code {result.returncode}')
        report = json.loads((folder / 'regressions/report.json').read_text())
        summary['errors'] += assess(report, expected)
        if report.get('source_start') != before: summary['errors'].append('Source changed before regression start')
        if changes(before, snapshot(ROOT)): summary['errors'].append('Source changed during verification')
        summary['status'] = 'failed' if summary['errors'] else 'passed'
    except KeyboardInterrupt:
        summary['status'] = 'interrupted'; summary['errors'].append('Verification interrupted')
    except (OSError, ValueError, KeyError, TypeError) as error:
        summary['status'] = 'failed'; summary['errors'].append(str(error))
    write(report_path, summary)
    print('Verification report:', report_path)
    status(folder)
    return 0 if summary['status'] == 'passed' else 1

if __name__ == '__main__':
    sys.exit(main())
