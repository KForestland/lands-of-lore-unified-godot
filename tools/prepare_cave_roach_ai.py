#!/usr/bin/env python3
"""Stage the original Roach AI tables (GLOBAL.MIX global\\ai\\Roach\\*.csv + global\\ai\\globalai.csv) as
scripts/lol2/cave_roach_ai_source.json for the live Roach disposition (docs/cave-roach-disposition.md).

Pure data reader: no native replay, no RE modules. Deterministic. Refuses an unsupported GLOBAL.MIX."""
import argparse, csv, hashlib, io, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lol2_source_format import parse_mix
from lol2_movie_format import ww_hash_v1

GLOBAL = '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'


def entry(archive, entries, name):
    e = entries.get(ww_hash_v1(name))
    if e is None: raise ValueError('Missing original entry ' + name)
    raw = archive[e['offset']:e['offset'] + e['size']]
    return raw, dict(name=name, key=e['key'], size=e['size'], sha256=hashlib.sha256(raw).hexdigest())


def table(raw, rows, columns):
    parsed = list(csv.reader(io.StringIO(raw.decode('ascii'))))[1:rows + 1]
    result = [[int(v) if v else 0 for v in r[1:columns + 1]] for r in parsed]
    if len(result) != rows or any(len(r) != columns for r in result): raise ValueError('CSV extent differs')
    if any(not -128 <= v <= 127 for r in result for v in r): raise ValueError('Signed byte out of range')
    return result


def build(game):
    archive = (game / 'GLOBAL.MIX').read_bytes()
    if hashlib.sha256(archive).hexdigest() != GLOBAL: raise ValueError('Unsupported GLOBAL.MIX')
    entries = {e['key']: e for e in parse_mix(archive)}
    goals_raw, goals_src = entry(archive, entries, 'global\\ai\\Roach\\goals.csv')
    actions_raw, actions_src = entry(archive, entries, 'global\\ai\\Roach\\actions.csv')
    effector_raw, effector_src = entry(archive, entries, 'global\\ai\\Roach\\effector.csv')
    global_raw, global_src = entry(archive, entries, 'global\\ai\\globalai.csv')
    goals = table(goals_raw, 46, 14)
    actions = table(actions_raw, 46, 15)
    effector = table(effector_raw, 58, 30)
    globalai = table(global_raw, 14, 30)
    return dict(
        version=1,
        global_sha256=GLOBAL,
        sources=[goals_src, actions_src, effector_src, global_src],
        # Scorer contracts (hive_ai_goal_choice / hive_ai_action_choice): weights = stat rows 0..29,
        # goals = previous-goal bias rows 32..45; goal 14 (initial) uses actions.csv row 0 for goals and effector.csv row 0 for actions
        # (both equal to the native-recorded tests/fixtures/cave_roach_ai_choice_native.json contracts).
        goals=dict(version=1, weights=goals[:30], goals=goals[32:46], initial_goal_bias=actions[0][:14]),
        actions=dict(version=1, weights=actions[:30], goals=actions[32:46], initial_goal_bias=effector[0][:15]),
        # Temporary-bank rows (AA208): global goal rows, then effector rows 9..57 for conditions 0..48.
        adjustments=dict(version=1, goals=globalai, conditions=effector[9:58]),
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--game', type=Path, required=True)
    ap.add_argument('--output', type=Path, default=Path(__file__).resolve().parent.parent / 'scripts/lol2/cave_roach_ai_source.json')
    a = ap.parse_args()
    try:
        data = build(a.game)
    except (OSError, ValueError) as error:
        print('error:', error, file=sys.stderr)
        return 1
    a.output.write_text(json.dumps(data, indent=1) + '\n')
    print(a.output)
    return 0


if __name__ == '__main__':
    sys.exit(main())
