#!/usr/bin/env python3
"""G-09: one command to make a lane worktree ready to build and gate, and a preflight that says what is missing.

  python3 tools/prepare_lane_worktree.py DEST [--from DONOR]     stage inputs + tools, then preflight
  python3 tools/prepare_lane_worktree.py DEST --preflight-only    only check

Staging copies, from the donor (default: the integration worktree ~/opus_work/lol2_r18):
  - every untracked runtime/test input via tools/stage_worktree.py (assets, native scripts, chain saves, user tests)
  - tmp/godot_dummy.sh, written fresh for this worktree (waits for 10 GiB free, Dummy audio, never sets XDG_DATA_HOME, so
    the runner's staged per-worktree user data stays in effect; the old shared wrapper forced lol2_r18/tmp/userdata)
  - tmp/virtual-display/ (private Xvfb; rendered single tests exit 2 without it)
Preflight checks the staged manifest digests, the Godot wrapper, Xvfb, free memory and the running Godot count against
the lane caps, the env files the qualification gate needs, and prints the gate command with the env it needs.
Nothing is copied over tracked files, code or saves.
"""
import argparse
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

DEFAULT_DONOR = Path('~/opus_work/lol2_r18')
QUAL = Path('~/AI_COMMS/act1_completion_20261017')
GATE_ENV = {
    'LOL2_ORIGINAL_GAME_EXE': '~/lol2_runtime_root/LOLG.EXE',
    'LOL2_EARNED_SAVES': str(QUAL / 'r18_qualification/campaign/userdata'),
    'LOL2_BODY_FIT_ARRIVAL_SAVE': '~/AI_COMMS/sol_lane/task3c_20261110/input_fixtures/act3_walk_l19_arrival_save.json',
    'LOL2_BODY_FIT_SEWER_SAVE': '~/AI_COMMS/sol_lane/task3c_20261110/input_fixtures/act3_walk_l19_sewer_save.json',
    # Missing on 2026-11-12: village escape tests FAILed and the mouse-refuses-E tests skipped silently (R103).
    'LOL2_VILLAGE_ESCAPE_SAVE': str(QUAL / 'r12f_qualification/campaign/userdata/act1_broken_runes_monastery_return.json'),
    'LOL2_HEADLESS_INPUT_FIXTURES': '~/AI_COMMS/sol_lane/f05_f04_20261110/input_fixtures',
}
WARN_GODOT, CRITICAL_GODOT, WARN_GIB, CRITICAL_GIB = 8, 10, 10, 6
GODOT_BIN = '/var/lib/flatpak/app/org.godotengine.Godot/current/active/files/bin/godot-bin'
HOST_LIBS = '~/opus_work/lol2_gameplay_20261014/tmp/godot_host_libs'
WRAPPER = f'''#!/bin/sh
# Per-worktree wrapper written by tools/prepare_lane_worktree.py. Waits for LOL2_MIN_FREE_GIB (default 10) GiB free, Dummy audio. It must NOT set
# XDG_DATA_HOME: the regression runner points it at this worktree's staged user data (tmp/staged_inputs/userdata).
while [ "$(awk '/MemAvailable/{{print int($2/1048576)}}' /proc/meminfo)" -lt "${{LOL2_MIN_FREE_GIB:-10}}" ]; do sleep 10; done
export LD_LIBRARY_PATH={HOST_LIBS}
exec {GODOT_BIN} --audio-driver Dummy "$@"
'''


SELECTOR_PACK_SHA256 = '945eaf8a887f63f80b67874089c772ebdd46c5ce65d18887221b0fda8c9597d1'   # generic_props/manifest.json (Sol, 356 outputs)
def free_gib():
    for line in Path('/proc/meminfo').read_text().splitlines():
        if line.startswith('MemAvailable:'):
            return int(line.split()[1]) / 1048576
    return 0.0


def godot_count():
    result = subprocess.run(['pgrep', '-c', '-x', 'godot-bin'], capture_output=True, text=True)
    return int(result.stdout.strip() or 0)


def wrapper_isolation(dest):
    """Problems if tmp/godot_dummy.sh, or a shell script it runs, sets XDG_DATA_HOME outside this worktree."""
    problems, seen = [], set()
    stack = [dest / 'tmp/godot_dummy.sh']
    while stack:
        script = stack.pop()
        if script in seen or not script.is_file():
            continue
        seen.add(script)
        text = script.read_text(errors='replace')
        for match in re.finditer(r'XDG_DATA_HOME=("?)([^"\s;]+)', text):
            target = Path(os.path.expandvars(match[2]))
            if not str(target.resolve()).startswith(str(dest.resolve()) + os.sep):
                problems.append(f'{script} sets XDG_DATA_HOME={target} (outside this worktree: runs share user data)')
        for match in re.finditer(r'(?:exec|\.|sh)\s+(/[^\s"]+\.sh)', text):
            stack.append(Path(match[1]))
    return problems


def geometry_move_problems(dest):
    """Problems if a geometry-move spec (scripts/lol2/geometry_moves/<AREA>.json) does not match its generated files.
    The game then refuses the move and loads the ORIGINAL map and nav (scripts/lol2/geometry_move.gd), so every test of
    that area would run on the unmoved map (void sweep 6d31407, 2026-11-14). Same sha256 checks as the game, plus the
    region-mover table it requires. Fix: python3 tools/prepare_geometry_move.py (and tools/prepare_region_mover.py)."""
    import hashlib
    problems, areas = [], []
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else 'missing'
    for spec_path in sorted((dest / 'scripts/lol2/geometry_moves').glob('*.json')):
        try:
            spec = json.loads(spec_path.read_text())
            area, inputs, outputs = spec['area'], spec['inputs'], spec['outputs']
        except (ValueError, KeyError, TypeError) as error:
            problems.append(f'geometry move {spec_path.name}: unreadable spec ({error})')
            continue
        maps, nav = dest / 'assets/lol2/generated/maps' / area, dest / 'assets/lol2/generated/creature_nav'
        checks = [('original pack', maps / 'area.json', inputs.get('pack')),
                  ('moved pack', maps / 'area_moved.json', outputs.get('pack')),
                  ('original nav', nav / f'{area}.json', inputs.get('nav')),
                  ('moved nav', nav / f'{area}.moved.json', outputs.get('nav'))]
        bad = [label for label, path, want in checks if sha(path) != want]
        if not (dest / 'scripts/lol2/region_mover' / f'{area}.moved.json').is_file():
            bad.append('moved region-mover table missing')
        if bad:
            problems.append(f'geometry move {area}: {", ".join(bad)} do not match the spec (the game would load the '
                            'original map; run tools/prepare_geometry_move.py and tools/prepare_region_mover.py)')
        areas.append(area)
    return problems, areas


def write_wrapper(dest):
    (dest / 'tmp').mkdir(exist_ok=True)
    wrapper = dest / 'tmp/godot_dummy.sh'
    wrapper.write_text(WRAPPER)
    wrapper.chmod(0o755)


def stage(dest, donor):
    tool = dest / 'tools/stage_worktree.py'
    if not tool.exists():
        sys.exit(f'{dest} has no tools/stage_worktree.py (is it a LoL2 worktree at r19-work or later?)')
    write_wrapper(dest)  # first, so a refused stage still leaves an isolated wrapper
    subprocess.run([sys.executable, str(tool), '--from', str(donor), str(dest)], check=True)
    display = donor / 'tmp/virtual-display'
    if display.exists() and not (dest / 'tmp/virtual-display').exists():
        shutil.copytree(display, dest / 'tmp/virtual-display', symlinks=True)


def preflight(dest):
    problems, notes = [], []
    # A live gate in this worktree (tmp/GATE_RUNNING, run_regressions.py) means: do not edit, commit, check out or start
    # another gate here until it ends (lead 2026-11-12).
    sys.path.insert(0, str(dest / 'tools'))
    try:
        from regression_source import gate_marker
        live = gate_marker(dest)
    except ImportError:
        live = None
    if live is not None:
        problems.append(f"GATE RUNNING in this worktree (pid {live.get('pid')}, out {live.get('out')}): no edits, commits or checkouts until it ends")
    check = subprocess.run([sys.executable, str(dest / 'tools/stage_worktree.py'), '--check', str(dest)],
                           capture_output=True, text=True)
    text = (check.stdout + check.stderr).strip().splitlines() or ['no output']
    (notes if check.returncode == 0 else problems).append('staged inputs: ' + text[-1] +
        ('' if check.returncode == 0 else ' (tests rewrite chain saves under tmp/; restage into a clean worktree for pristine inputs)'))
    wrapper = dest / 'tmp/godot_dummy.sh'
    if not wrapper.exists():
        problems.append('tmp/godot_dummy.sh missing')
    elif not os.access(wrapper, os.X_OK):
        problems.append('tmp/godot_dummy.sh not executable')
    for line in wrapper_isolation(dest):
        problems.append(line)
    if not (dest / 'tmp/virtual-display/root/usr/bin/Xvfb').exists():
        problems.append('tmp/virtual-display missing: rendered tests run alone will exit 2')
    for name, value in GATE_ENV.items():
        if not Path(value).exists():
            problems.append(f'{name} target missing: {value}')
    # Every F2 playtest start in the manifest has its save staged with the pinned sha256 (a cut must never ship a dead start).
    manifest = dest / 'scripts/lol2/playtest_starts.json'
    if manifest.is_file():
        import hashlib
        data = json.loads(manifest.read_text())
        rows = data if isinstance(data, list) else data.get('starts', data.get('entries', []))
        dead = []
        for row in rows:
            path = dest / 'assets/lol2/generated/playtest_starts' / str(row.get('save', ''))
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != str(row.get('sha256', '')):
                dead.append(str(row.get('id')))
        (problems if dead else notes).append(f'F2 starts: {len(rows) - len(dead)}/{len(rows)} saves staged with the pinned sha256'
            + (f'; dead: {", ".join(dead)} (tools/prepare_playtest_starts.py)' if dead else ''))
    # The generic prop selector pack (Cemetery chargers, L9 tower orb; scripts/lol2/prop_selector_view.gd): without it the
    # views attach to nothing and the chargers are dead (r19g candidate 2026-11-13). Pinned by its manifest's sha256 and
    # every file it lists; generated by tools/prepare_generic_prop_media.py (Sol) - stage it from a donor that has it.
    if (dest / 'scripts/lol2/prop_selector_view.gd').is_file():
        import hashlib
        pack = dest / 'assets/lol2/generated/generic_props'
        manifest = pack / 'manifest.json'
        # The revision's own pin (tests/fixtures, the one stage_worktree checks) wins; the constant is the fallback for
        # revisions without it (G-03 L20 424ef99 moved the pin, 2026-11-15).
        pin_file = dest / 'tests/fixtures/generic_prop_media_manifest.json'
        pinned = hashlib.sha256(pin_file.read_bytes()).hexdigest() if pin_file.is_file() else SELECTOR_PACK_SHA256
        if not manifest.is_file():
            problems.append('generic prop selector pack missing: assets/lol2/generated/generic_props/manifest.json')
        elif hashlib.sha256(manifest.read_bytes()).hexdigest() != pinned:
            problems.append(f'generic prop selector pack: manifest sha256 is not the pinned {pinned[:12]}')
        else:
            files = json.loads(manifest.read_text()).get('files', {})
            bad = [name for name, entry in files.items() if not (pack / name).is_file()
                   or hashlib.sha256((pack / name).read_bytes()).hexdigest() != entry.get('sha256')]
            (problems if bad else notes).append(f'generic prop selector pack: {len(files) - len(bad)}/{len(files)} files match'
                + (f'; bad: {", ".join(bad[:3])}' if bad else ''))
    moves, move_areas = geometry_move_problems(dest)
    problems.extend(moves)
    if move_areas and not moves:
        notes.append(f'geometry moves: {", ".join(move_areas)} generated files match their specs')
    gib, count = free_gib(), godot_count()
    state = 'CRITICAL' if count > CRITICAL_GODOT or gib < CRITICAL_GIB else 'WARN' if count > WARN_GODOT or gib < WARN_GIB else 'ok'
    (problems if state == 'CRITICAL' else notes).append(f'memory {state}: {count} godot-bin, {gib:.1f} GiB free')
    for line in notes:
        print('  ok   ' + line)
    for line in problems:
        print('  FIX  ' + line)
    env = ' '.join(f'{k}={v}' for k, v in GATE_ENV.items())
    print('\nGate command (one test):')
    print(f'  cd {dest} && {env} python3 tools/run_regressions.py --suite all --test NAME --godot tmp/godot_dummy.sh --timeout 1500 --out OUT')
    print('Full sweep: same without --test; the lead/integration lane runs it, lanes run targeted tests.')
    return not problems


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('dest')
    parser.add_argument('--from', dest='donor', default=str(DEFAULT_DONOR))
    parser.add_argument('--preflight-only', action='store_true')
    parser.add_argument('--wrapper-only', action='store_true', help='only (re)write tmp/godot_dummy.sh, then preflight')
    args = parser.parse_args()
    dest = Path(args.dest).resolve()
    if args.wrapper_only:
        write_wrapper(dest)
    elif not args.preflight_only:
        stage(dest, Path(args.donor).resolve())
    print(f'Preflight {dest}:')
    sys.exit(0 if preflight(dest) else 1)


if __name__ == '__main__':
    main()
