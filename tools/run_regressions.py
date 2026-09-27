#!/usr/bin/env python3
"""Run sequential Godot regressions with logs, timeouts and a JSON summary."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import signal
import selectors
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
PORTABLE = [('hive_attack_portable_test', 'headless')]
# Keep published suites limited to tests available in this checkout.
CORE = PORTABLE
SUITES = {'portable': PORTABLE, 'core': CORE, 'all': CORE}


def run_one(command, timeout, env):
    started = time.monotonic()
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   env=env, start_new_session=True)
    except OSError as error:
        return 127, str(error), False, time.monotonic() - started
    chunks = []
    deadline = started + timeout
    script_error_deadline = None
    timed_out = False
    def kill_group():
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    # Godot assertions stop a test coroutine without exiting the engine. Keep
    # its diagnostic/backtrace, then stop this test group instead of waiting minutes.
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        tail = b""
        while True:
            limit = min(deadline, script_error_deadline or deadline)
            remaining = limit - time.monotonic()
            if remaining <= 0:
                timed_out = script_error_deadline is None
                kill_group()
                break
            if not selector.select(remaining):
                continue
            data = os.read(process.stdout.fileno(), 65536)
            if not data:
                break
            chunks.append(data)
            sample = tail + data
            if script_error_deadline is None and re.search(rb"(?:^|\n)SCRIPT ERROR:", sample):
                script_error_deadline = time.monotonic() + 0.2
            tail = sample[-64:]
    try:
        rest, _ = process.communicate(timeout=max(0.01, min(deadline, script_error_deadline or deadline)-time.monotonic()))
    except subprocess.TimeoutExpired:
        timed_out = script_error_deadline is None
        kill_group()
        rest, _ = process.communicate()
    chunks.append(rest)
    code = 124 if timed_out else (1 if script_error_deadline is not None else process.returncode)
    return code, b"".join(chunks).decode(errors="replace"), timed_out, time.monotonic() - started


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=SUITES, default='core')
    parser.add_argument('--godot', nargs='+', help='Command prefix, e.g. --godot flatpak run org.godotengine.Godot')
    parser.add_argument('--out', type=Path, help='Output directory; default: project tmp/regressions/<UTC timestamp>')
    parser.add_argument('--timeout', type=float, default=300, help='Maximum seconds per test (continuous quest walks can exceed 120 seconds)')
    parser.add_argument('--display', help='Use an existing X11 display; rendered tests otherwise start private Xvfb.')
    parser.add_argument('--test', action='append', default=[], help='Run only this named test from the selected suite; repeat for several tests')
    parser.add_argument('--list', action='store_true', help='List selected tests without running them')
    args = parser.parse_args()
    if not 0 < args.timeout < float('inf'):
        parser.error('--timeout must be finite and positive')
    tests = SUITES[args.suite]
    if args.test:
        unknown = set(args.test) - {name for name, _ in tests}
        if unknown: parser.error('Tests outside selected suite: ' + ', '.join(sorted(unknown)))
        tests = [(name, mode) for name, mode in tests if name in args.test]
    if args.list:
        for name, mode in tests:
            print(f'{mode:8} {name}')
        return 0
    if args.display is None and any(mode == "rendered" for _, mode in tests):
        return subprocess.call([sys.executable, str(ROOT / "tools/run_isolated_regressions.py"), *sys.argv[1:]])
    godot = args.godot
    if not godot:
        executable = shutil.which('godot') or shutil.which('godot4')
        if executable:
            godot = [executable]
        elif shutil.which('flatpak'):
            godot = ['flatpak', 'run', 'org.godotengine.Godot']
        else:
            parser.error('Godot not found; provide --godot COMMAND')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    output = (args.out or ROOT / 'tmp' / 'regressions' / stamp).resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {'suite': args.suite, 'project': str(ROOT), 'started_utc': stamp,
              'godot': godot, 'filtered': bool(args.test), 'suite_test_count': len(SUITES[args.suite]), 'selected_tests': [name for name, _ in tests], 'complete': False, 'passed': False, 'tests': []}
    def save():
        temporary = output / 'report.json.tmp'
        temporary.write_text(json.dumps(report, indent=2) + '\n')
        temporary.replace(output / 'report.json')
    save()
    for index, (name, mode) in enumerate(tests, 1):
        print(f'[{index}/{len(tests)}] {name} ({mode})', flush=True)
        command = godot + (['--headless'] if mode == 'headless' else [
            '--display-driver', 'x11', '--rendering-method', 'gl_compatibility',
            '--resolution', '1280x720', '--fixed-fps', '60'])
        command += ['--path', str(ROOT), '--script', f'res://tests/{name}.gd']
        code, log, timed_out, elapsed = run_one(command, args.timeout, {**os.environ, 'DISPLAY': args.display or os.environ.get('DISPLAY', ':0')})
        logfile = output / f'{name}.log'
        logfile.write_text(log)
        errors = [line for line in log.splitlines() if re.search(
            r'SCRIPT ERROR|ERROR:|Assertion failed|Traceback|\bFAIL(?:ED)?\b', line)]
        passed = code == 0 and not errors and bool(re.search(r'\bpass(?:ed)?\b', log, re.IGNORECASE))
        report['tests'].append({'name': name, 'mode': mode, 'passed': passed,
            'returncode': code, 'timed_out': timed_out, 'seconds': round(elapsed, 2),
            'log': logfile.name, 'errors': errors})
        save()
        print(f'  {"PASS" if passed else "FAIL"} ({elapsed:.2f}s)' +
              ('' if passed else f' — see {logfile}'), flush=True)
    report['complete'] = True
    report['passed'] = all(row['passed'] for row in report['tests'])
    save()
    passed = sum(row['passed'] for row in report['tests'])
    print(f'{passed}/{len(tests)} passed. Report: {output / "report.json"}')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
