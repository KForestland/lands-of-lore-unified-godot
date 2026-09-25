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
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
PORTABLE = [('hive_attack_portable_test', 'headless')]
CORE = PORTABLE + [(name, 'headless') for name in [
    'hive_spatial_admission_test',
    'hive_damage_calculation_test',
    'hive_player_health_adjustment_test',
    'hive_blocked_player_damage_test',
    'hive_executioner_damage_state_test',
    'hive_path_control_test',
    'hive_ai_action_choice_test',
    'hive_ai_goal_choice_test',
    'hive_ai_animation_commit_test',
    'hive_executioner_pose_test',
    'hive_source_pose_runtime_test',
    'hive_outcome_transition_test',
    'hive_executioner_runtime_test',
    'hive_executioner_action_test',
    'hive_action_admission_test',
	'hive_ai_schedule_test',
	'hive_timing_state_test',
    'hive_marker_checkpoint_test', 'hive_actor_marker_test', 'hive_marker_runtime_test', 'hive_startup_geometry_test',
    'hive_fixed_geometry_test', 'hive_condition_geometry_test', 'hive_condition_runtime_test', 'hive_remaining_conditions_test', 'hive_player_conditions_test', 'hive_actor_conditions_test', 'hive_effective_stats_test', 'hive_clock_runtime_test', 'hive_initial_stats_test', 'hive_attack_runtime_test', 'hive_attack_feedback_test',
    'hive_stat_adjustments_test', 'hive_source_adjustments_test']]
HIVE = [(name, 'headless') for name in [
    'magic_shop_plan_test', 'monastery_offer_plan_test', 'hive_rune_response_test', 'act_one_departure_state_test', 'hive_rune_transaction_test', 'hive_magic_reward_test', 'hive_curse_state_test', 'monastery_quest_state_test', 'hive_rune_room_test',
    'hive_executioner_scene_save_test',
    'hive_schedule_scene_save_test',
	'hive_timing_scene_save_test',
    'hive_playback_rate_test',
    'hive_marker_scene_save_test', 'hive_chasm_save_test', 'hive_quest_save_test', 'jungle_save_test']] + [
    (name, 'rendered') for name in ['magic_shop_media_test', 'monastery_offer_responses_test', 'hive_rune_speech_test', 'hive_ancient_stone_test', 'player_starting_magic_test', 'player_magic_handoff_test', 'hive_executioner_live_test', 'hive_rune_light_test', 'hive_rune_copy_test', 'hive_rune_entry_test', 'hive_rune_media_test', 'hive_wax_return_test', 'hive_flute_return_test', 'hive_small_route_test', 'hive_curse_runtime_test', 'player_curse_test', 'hive_curse_wax_walk_test', 'hive_elevator_test', 'hive_lift_wax_walk_test', 'hive_jump_test', 'hive_wax_test', 'bacatta_rooms_test', 'monastery_rooms_test', 'monastery_room_media_test', 'hive_executioner_sprite_test', 'hive_chasm_input_test', 'hive_warriors_test',
    'hive_interface_test', 'hive_resume_launcher_test', 'hive_quest_walk_test',
    'hive_nest_test', 'hive_route_test', 'jungle_village_gate_test', 'jungle_followup_test']]
SUITES = {'portable': PORTABLE, 'core': CORE, 'hive': HIVE, 'all': CORE + HIVE}


def run_one(command, timeout, env):
    started = time.monotonic()
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, env=env, start_new_session=True)
    except OSError as error:
        return 127, str(error), False, time.monotonic() - started
    timed_out = False
    try:
        log, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        # Terminate only the process group launched for this test.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        log, _ = process.communicate()
    return (124 if timed_out else process.returncode), log, timed_out, time.monotonic() - started


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=SUITES, default='core')
    parser.add_argument('--godot', nargs='+', help='Command prefix, e.g. --godot flatpak run org.godotengine.Godot')
    parser.add_argument('--out', type=Path, help='Output directory; default: project tmp/regressions/<UTC timestamp>')
    parser.add_argument('--timeout', type=float, default=300, help='Maximum seconds per test (continuous quest walks can exceed 120 seconds)')
    parser.add_argument('--display', default=os.environ.get('DISPLAY', ':0'))
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
        code, log, timed_out, elapsed = run_one(command, args.timeout, {**os.environ, 'DISPLAY': args.display})
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
