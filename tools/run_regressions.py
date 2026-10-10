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
PORTABLE = [('hive_attack_portable_test', 'headless')]
CORE = PORTABLE + [(name, 'headless') for name in [
    'item_catalog_test',
    'hive_spatial_admission_test',
    'hive_damage_calculation_test',
    'player_mitigation_test',
    'dawn_spell_motion_test',
    'dawn_spell_contact_test',
    'dawn_explosion_calculation_test',
    'dawn_explosion_test',
    'dawn_admission_test',
    'dawn_selection_test',
    'dawn_spell_scoring_test',
    'dawn_ai_decision_test',
    'dawn_cast_entry_test',
    'vqa_partial_codebook_media_test',
    'dawn_player_damage_test',
    'dawn_combined_damage_test',
    'dawn_projectile_store_test',
    'dawn_projectile_launch_test', 'dawn_projectile_world_test',
    'dawn_heading_test', 'dawn_cast_target_test', 'dawn_cast_dispatch_test',
    'hive_dawn20_state_test', 'monastery_library_attack_test', 'dawn_spell_bolts_test', 'dawn_spell7_chain_test', 'dawn_spell58_plasma_test',
    'dawn_cast_completion_test',
    'dawn_temporary_effects_test',
    'dawn_active_spells_test',
    'dawn_object_distance_test',
    'hive_player_health_adjustment_test',
    'hive_blocked_player_damage_test',
    'hive_executioner_damage_state_test',
    'hive_path_control_test',
    'cave_roach_population_state_test',
    'cave_melee_reward_test',
    'cave_roach_live_state_test',
    'cave_roach_live_behavior_test',
    'jungle_dino_population_state_test',
    'jungle_dino_population_portable_test',
    'museum_skeleton_population_state_test',
    'museum_skeleton_live_test',
    'cave_guard_population_state_test',
    'cave_lurking_roach_state_test',
    'cave_lurking_roach_live_test',
    'cave_wild_roach_state_test',
    'cave_wild_roach_live_test',
    'cave_eyes_state_test',
    'cave_eyes_save_roundtrip_test',
    'cave_scenic_guard_state_test',
    'cave_scenic_guard_live_test',
    'player_defense_state_test',
    'cave_guard_live_test',
    'creature_navigation_clock_test',
    'museum_control_live_test',
    'museum_sword_skeleton_test',
    'museum_control96_state_test',
    'cave_guard_controls_state_test',
    'cave_captain_state_test',
    'jungle_bacatta_state_test',
    'jungle_kelsrick_state_test',
    'jungle_bacatta65_state_test',
    'jungle_bacatta57_state_test',
    'jungle_drunk_state_test',
    'jungle_village_alarm_state_test',
    'jungle_inner_gate_state_test',
    'jungle_kityara_state_test',
    'jungle_chief_hut_state_test',
    'jungle_dawn_state_test',
    'jungle_actor62_state_test',
    'jungle_exit_encounter_state_test',
    'jungle_exit_encounter_live_test',
    'source_control_contact_test',
    'jungle_villager_live_test',
    'creature_navigation_test',
    'jungle_dino_live_test',
    'hive_population_position_save_test',
    'jungle_dino_idle_live_test',
    'scripted_creature_audio_state_test',
    'museum_creature_audio_playback_test',
    'museum_creature_audio_save_test',
    'cave_guard_audio_save_test',
    'cave_roach_audio_save_test',
    'cave_entrance_roach_audio_save_test',
    'jungle_dino_audio_state_test',
    'jungle_dino_audio_playback_test',
    'jungle_dino_audio_save_test',
    'jungle_dino_damage_atomic_test',
    'cave_roach_population_visual_state_test',
    'cave_roach_population_choice_test',
    'cave_roach_population_live_test',
    'cave_roach_startup_test',
    'cave_roach_population_save_test',
    'cave_roach_effective_stats_test',
    'cave_roach_ai_choice_test',
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
CORE += [('fire_crystal_live_test','rendered'), ('museum_sconce_recharge_test','rendered'), ('cave_splash_timer_boundary_test','headless'), ('cave_side_chamber_live_test','rendered'), ('cave_prop83_collision_rewind_test','rendered'), ('cave_prop83_lift_live_test','rendered'), ('cave_prop83_lift_state_test','headless'), ('cave_stone_manafoil_live_test','rendered'), ('hive_net_exile_live_test','rendered'), ('hive_reaver_escape_test','rendered'), ('hive_reaver_amber_live_test','rendered'), ('museum_prism_test', 'rendered'), ('museum_long_arm_live_test','rendered'),('museum_long_arm_escape_test','rendered')]
CORE += [('museum_sconce_burn_test', 'rendered')]
CORE += [('hive_reaver_pillars_live_test', 'rendered')]
CORE += [('tavern_return_live_test', 'rendered')]
CORE += [('liz_room_live_test', 'rendered'), ('tavern_liz_ordinary_route_test', 'rendered')]
CORE += [('cave_guard38_loot_test', 'rendered')]
CORE += [('cave_guard39_loot_test', 'rendered')]
CORE += [('monastery_dawn_dampen_test', 'rendered'), ('jungle_beehives_live_test', 'rendered'), ('museum_blood_loot_test', 'rendered'), ('cave_guard54_loot_test', 'rendered'), ('jungle_kelsrick_loot_test', 'rendered'), ('cave_guard52_53_loot_test', 'rendered')]
CORE += [('cave_captain_loot_test', 'rendered')]
CORE += [('jungle_harvest_live_test', 'rendered')]
CORE += [('museum_key_locks_state_test', 'headless'), ('museum_key_locks_live_test', 'rendered'), ('museum_gallery_test', 'rendered'), ('museum_checkpoint_test', 'rendered'), ('museum_jump_playtest_test', 'rendered')]
CORE += [('net_exile_onhit_hive_test', 'rendered'), ('net_exile_onhit_jungle_test', 'rendered')]
CORE += [('prism_blind_rules_test', 'headless'), ('prism_effects_museum_test', 'rendered'), ('prism_blind_jungle_test', 'rendered'), ('prism_blind_hive_test', 'rendered')]
CORE += [('dawn_modern_combat_test', 'rendered'), ('dawn_modern_spells_test', 'rendered'), ('dawn_projectile_hosts_test', 'rendered'), ('hive_dawn20_region478_test', 'rendered'), ('hive_dawn20_live_test', 'rendered'), ('monastery_library_attack_live_test', 'rendered'), ('cave_review_captain_guard_test', 'rendered'), ('cave_curse_integration', 'rendered'), ('cave_museum_transfer_test', 'rendered'), ('cave_demo_controls_test', 'rendered'), ('cave_guard_controls_live_test', 'rendered'), ('captain_equipment_transport_test', 'rendered'), ('jungle_exit_woman_live_test', 'rendered'), ('jungle_exit_woman_earned_test', 'rendered'), ('cave_captain_live_test', 'rendered'), ('jungle_bacatta_live_test', 'rendered'), ('jungle_kelsrick_live_test', 'rendered'), ('jungle_bacatta65_live_test', 'rendered'), ('jungle_bacatta57_live_test', 'rendered'), ('jungle_village_alarm_live_test', 'rendered'), ('jungle_drunk_live_test', 'rendered'), ('jungle_chief_hut_live_test', 'rendered'), ('jungle_kityara_live_test', 'rendered'), ('jungle_kityara_hostile_test', 'rendered'), ('jungle_kityara_shop_death_test', 'rendered'), ('jungle_chief_hut_movie_lock_test', 'rendered'), ('jungle_inner_gate_live_test', 'rendered'), ('jungle_dawn_live_test', 'rendered'), ('jungle_actor62_live_test', 'rendered'), ('jungle_world_items_live_test', 'rendered'), ('cave_scenic_guard_spark_test', 'rendered'), ('museum_control96_live_test', 'rendered'), ('jungle_exit_scene_test', 'rendered'), ('cave_eyes_live_test', 'rendered'), ('cave_scenic_guard_scene_test', 'rendered')]
HIVE = [(name, 'headless') for name in [
    'hive_boulder_contact_state_test', 'hive_boulder_impulse_test', 'hive_boulder_damage_test', 'hive_boulder_audio_state_test', 'hive_boulder_actor_state_test', 'hive_boulder_sprite_test', 'hive_moving_geometry_test', 'hive_boulder_sequence_test',
    'hive_worm_animation_test', 'hive_warrior_selection_test', 'hive_warrior_animation_test', 'hive_ambush_state_test', 'hive_rune_population_state_test', 'hive_return_population_state_test', 'player_spark_aura_state_test', 'player_ancient_charge_state_test', 'executioner_spell_reward_test', 'cave_aloe_effect_test', 'museum_broken_case_test', 'museum_broken_thohan_test', 'morgan_orb_blessing_test', 'moff_revisit_plan_test', 'moff_revisit_state_test', 'jungle_source_pickups_test', 'player_item_effects_test', 'magic_shop_callbacks_test', 'magic_shop_offer_state_test', 'hive_live_melee_reward_test', 'weapon_shop_state_test', 'magic_shop_plan_test', 'monastery_offer_plan_test', 'hive_rune_response_test', 'act_one_departure_state_test', 'hive_rune_transaction_test', 'hive_rune_wax_identity_test', 'hive_magic_reward_test', 'hive_curse_state_test', 'monastery_quest_state_test', 'hive_rune_room_test',
    'hive_executioner_scene_save_test',
    'hive_schedule_scene_save_test',
	'hive_timing_scene_save_test',
    'hive_playback_rate_test',
    'hive_marker_scene_save_test', 'hive_chasm_save_test', 'hive_quest_save_test', 'jungle_save_test', 'jungle_exit_woman_state_test']] + [
    (name, 'rendered') for name in ['player_defense_live_test', 'hive_rune_population_live_test', 'hive_boulder_audio_live_test', 'hive_boulder_contact_earned_walk_test', 'hive_boulder_contact_live_test', 'hive_boulders_live_test', 'hive_boulder_surfaces_live_test', 'hive_warrior_attack_live_test', 'hive_warrior_death_live_test', 'world_fall_boundary_test', 'hive_ambush_spark_test', 'hive_ambush_live_test', 'player_spark_rewards_test', 'hive_return_population_live_test', 'player_spark_aura_live_test', 'hive_curse_gates_live_test', 'hive_spell_reward_live_test', 'cave_aloe_live_use_test', 'jungle_aloe_use_test', 'jungle_sap_use_test', 'jungle_fruit_use_test', 'museum_broken_thohan_live_test', 'morgan_blessing_test', 'moff_revisit_room_test', 'weapon_shop_offer_room_test', 'jungle_source_pickups_live_test', 'player_item_live_test', 'magic_shop_hotspot_room_test', 'magic_shop_inventory_test', 'monastery_side_rooms_test', 'weapon_shop_room_test', 'magic_shop_media_test', 'magic_shop_room_test', 'monastery_offer_responses_test', 'hive_rune_speech_test', 'hive_ancient_stone_test', 'player_starting_magic_test', 'player_magic_handoff_test', 'cave_fighting_handoff_test', 'hive_executioner_live_test', 'hive_weapon_admission_test', 'hive_rune_light_test', 'hive_rune_copy_test', 'hive_rune_jungle_wax_test', 'hive_rune_entry_test', 'hive_rune_media_test', 'hive_wax_return_test', 'hive_flute_return_test', 'hive_small_route_test', 'hive_curse_runtime_test', 'player_curse_test', 'hive_curse_wax_walk_test', 'hive_elevator_test', 'hive_lift_wax_walk_test', 'hive_jump_test', 'hive_wax_test', 'bacatta_rooms_test', 'monastery_rooms_test', 'monastery_room_media_test', 'hive_executioner_sprite_test', 'hive_chasm_input_test', 'hive_warriors_test',
    'hive_interface_test', 'hive_resume_launcher_test', 'hive_quest_walk_test', 'kelsrick_inner_gate_walk_test', 'jungle_chief_hut_walk_test',
    'hive_nest_test', 'hive_route_test', 'jungle_village_gate_test', 'jungle_followup_test']]
SUITES = {'portable': PORTABLE, 'core': CORE, 'hive': HIVE, 'all': CORE + HIVE}


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
        if name == 'cave_demo_controls_test': command += ['--', '--demo-interface']
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
    report['source_end'] = source_snapshot(ROOT)
    report['source_changed_files'] = source_changes(report['source_start'], report['source_end'])
    report['source_stable'] = not report['source_changed_files']
    report['complete'] = True
    report['passed'] = all(row['passed'] for row in report['tests'])
    save()
    passed = sum(row['passed'] for row in report['tests'])
    print(f'{passed}/{len(tests)} passed. Report: {output / "report.json"}')
    if not report['source_stable']:
        print('Source changed during this run; results do not certify a single source revision. See source_changed_files in report.json.')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
