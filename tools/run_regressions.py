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
from regression_source import snapshot as source_snapshot, changes as source_changes

ROOT = Path(__file__).resolve().parents[1]
# Test registry (WORKFLOW_PLAN W4, 2026-10-31): every test self-registers as tests/registry/<name>.json
# {"name", "suite": "portable" | "core" | "hive", "mode": "headless" | "rendered", "order": N}. The lists below are rebuilt from
# those files in `order` and keep the former API and membership exactly: PORTABLE, CORE = PORTABLE + the core entries, HIVE,
# SUITES = {portable, core, hive, all = core + hive} (proven by the before/after dump in docs/w4-registry-receipt.json).
# A test without a registry file is not run; two files for one name, a bad suite or mode, or (W16) equal orders are allowed: ties run in name order.
REGISTRY = ROOT / 'tests/registry'
# Optional per-test "needs" (2026-10-31 triage): {"env": [VAR, ...] the test reads (unset -> the test is SKIPPED with the reason, not
# failed), "args": [...] appended after `--` on its command line, "fixtures": [...] files/saves it expects (listed for the
# qualification, not checked here), "chain": "..." = the test is one process of a chain another tool drives (always SKIPPED here
# with that reason), "note": free text}. A skipped test is reported with skipped=true and counts in neither pass nor fail.
NEEDS = {}


def _load_registry():
    rows = {'portable': [], 'core': [], 'hive': []}
    for path in sorted(REGISTRY.glob('*.json')):
        entry = json.loads(path.read_text())
        name, suite, mode, order = entry['name'], entry['suite'], entry['mode'], int(entry['order'])
        if path.stem != name:
            raise ValueError(f'{path.name}: registered name {name!r} does not match the file name')
        if suite not in rows or mode not in ('headless', 'rendered'):
            raise ValueError(f'{path.name}: suite {suite!r} / mode {mode!r}')
        if not (ROOT / 'tests' / f'{name}.gd').exists():
            raise ValueError(f'{path.name}: tests/{name}.gd does not exist')
        needs = entry.get('needs')
        if needs is not None:
            if not isinstance(needs, dict) or set(needs) - {'env', 'args', 'fixtures', 'chain', 'note'}:
                raise ValueError(f'{path.name}: needs must be a dict with env/args/fixtures/chain/note')
            NEEDS[name] = needs
        rows[suite].append((order, name, mode))
    out = {}
    for suite, items in rows.items():
        # W16 (2026-11-01): equal orders are allowed and run in name order, so two lanes appending tests never renumber.
        out[suite] = [(name, mode) for _, name, mode in sorted(items)]
    return out


_REGISTRY = _load_registry()
PORTABLE = _REGISTRY['portable']
CORE = PORTABLE + _REGISTRY['core']
HIVE = _REGISTRY['hive']
SUITES = {'portable': PORTABLE, 'core': CORE, 'hive': HIVE, 'all': CORE + HIVE}


def run_one(command, timeout, env, log_path=None):
    if log_path is not None:
        log_path = Path(log_path)
        log_path.write_bytes(b"")
    def append_log(data):
        if log_path is not None:
            with log_path.open("ab") as stream:
                stream.write(data)
    started = time.monotonic()
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   env=env, start_new_session=True)
    except OSError as error:
        append_log(str(error).encode())
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
            append_log(data)
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
    append_log(rest)
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
    report['source_start'] = source_snapshot(ROOT)
    report['source_stable'] = None
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
        needs = NEEDS.get(name, {})
        skip_reason = ''
        if needs.get('chain'):
            skip_reason = 'chain: ' + str(needs['chain'])
        else:
            missing = [v for v in needs.get('env', []) if not os.environ.get(v)]
            if missing: skip_reason = 'needs env ' + ', '.join(missing)
        if skip_reason:
            report['tests'].append({'name': name, 'mode': mode, 'passed': False, 'skipped': True, 'reason': skip_reason,
                'returncode': None, 'timed_out': False, 'seconds': 0.0, 'log': None, 'errors': []})
            save()
            print(f'  SKIPPED ({skip_reason})', flush=True)
            continue
        if needs.get('args'):
            command += (['--'] if '--' not in command else []) + [os.path.expandvars(str(a)) for a in needs['args']]
        if name in ('cave_stalactites_prop83_test', 'cave_cfall_live_test', 'cave_old_orc_lava_test', 'cave_tar_fires_test', 'cave_prop223_test', 'cave_pillar_trap_test', 'cave_shrine_doors_test', 'cave_boulder1333_test', 'hud_form_portraits_ui_scale_test', 'help_system_test', 'playtest_feedback_locked_overlays_test', 'playtest_feedback_jungle_lock_test', 'playtest_feedback_hosts_test', 'combat_feedback_inventory_test', 'dev_diagnostics_hosts_test', 'cave_demo_controls_test', 'classic_hud_live_test', 'classic_hud_actions_test', 'classic_hud_layout_test', 'classic_hud_acceptance_test', 'player_continuity_chain_test', 'player_continuity_restart_test', 'player_handoff_contract_test', 'player_continuity_hive_return_test', 'player_continuity_hive_restart_test', 'player_continuity_room_test', 'player_continuity_room_restart_test', 'village_doorway_load_test', 'act1_recovery_cave_test', 'cave_defeat_recovery_anchor_test', 'cave_movie_facing_region631_test', 'act1_recovery_museum_test', 'act1_recovery_jungle_test', 'act1_recovery_hive_test', 'target_status_overlap_test'): command += ['--', '--demo-interface']
        if name == 'l9_gate_entry_test':
            command += ['--', '--l9-preview', '--original-game-exe=' + os.environ.get(
                'LOL2_ORIGINAL_EXE', '~/lol2_runtime_root/LOLG.EXE')]
        logfile = output / f'{name}.log'
        report['current_test'] = {'name': name, 'index': index, 'mode': mode,
                                  'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                                  'timeout_seconds': args.timeout, 'log': logfile.name}
        save()
        code, log, timed_out, elapsed = run_one(command, args.timeout, {**os.environ, 'DISPLAY': args.display or os.environ.get('DISPLAY', ':0')}, logfile)
        logfile.write_text(log)
        errors = [line for line in log.splitlines() if re.search(
            r'SCRIPT ERROR|ERROR:|Assertion failed|Traceback|\bFAIL(?:ED)?\b', line)]
        passed = code == 0 and not errors and bool(re.search(r'\bpass(?:ed)?\b', log, re.IGNORECASE))
        report['current_test'] = None
        report['tests'].append({'name': name, 'mode': mode, 'passed': passed,
            'returncode': code, 'timed_out': timed_out, 'seconds': round(elapsed, 2),
            'log': logfile.name, 'errors': errors})
        save()
        print(f'  {"PASS" if passed else "FAIL"} ({elapsed:.2f}s)' +
              ('' if passed else f' — see {logfile}'), flush=True)
    report['source_end'] = source_snapshot(ROOT)
    report['source_changed_files'] = source_changes(report['source_start'], report['source_end'])
    report['source_stable'] = not report['source_changed_files']
    report['complete'] = True
    report['passed'] = all(row['passed'] or row.get('skipped') for row in report['tests'])
    report['skipped'] = [row['name'] for row in report['tests'] if row.get('skipped')]
    save()
    passed = sum(row['passed'] for row in report['tests'])
    skipped = len(report['skipped'])
    print(f'{passed}/{len(tests) - skipped} passed' + (f', {skipped} skipped (needs)' if skipped else '') + f'. Report: {output / "report.json"}')
    if not report['source_stable']:
        print('Source changed during this run; results do not certify a single source revision. See source_changed_files in report.json.')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
