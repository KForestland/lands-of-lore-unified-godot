#!/usr/bin/env python3
"""Audit an earned Dark Halls detour chain (tools/run_act1_fresh_chain.py --dark-halls-detour, or the three
dark_halls_earned_detour_test phases (enter/finish/depart/resume) run by hand on an earned repaired-monastery save).

Checks, from the actual files only:
  - chain receipts (with --run): legs 01..10 and the three detour legs started and exited 0, in order, once each,
    then "DARK HALLS DETOUR CHAIN COMPLETE";
  - each phase receipt passed, ran in its own process (distinct pids) and on one source commit;
  - hash links: earned monastery save -> enter input; enter F5 Dark Halls save -> finish input; finish F5 Jungle save
    -> depart input; depart output = the darker-jungle save; the kept copies match those hashes;
  - save contents: six windows (not done) in the Dark Halls save; seven windows, done, soul +1 in the Jungle save and
    the darker save; every earned item kept; the loot grants taken by E added; Rix alive and soul not lowered by him;
    the darker save's departure phase; creature deaths present in the saved population.
Usage: LOL2_CHAIN_SAVES=<user://tests dir> audit_dark_halls_detour_chain.py [--run <chain out dir>] [--json OUT]
"""
import argparse, hashlib, json, os, re, sys
from pathlib import Path

LEGS = ['01_cave', '02_museum', '03_jungle_hive', '04_flute', '05_wax', '06_runes', '07_rune_return', '08_knowledge',
        '09_translation', '10_repair', '11_dark_halls_enter', '12_dark_halls_finish', '13_dark_halls_depart', '14_dark_halls_resume']
WINDOWS_FIRST = [246, 247, 251, 250, 249, 248]
WINDOW_LAST = 237

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', help='chain output directory (chain.out); omit for hand-run phases')
    parser.add_argument('--json', help='write the audit result here')
    parser.add_argument('--project', help='campaign project (default: three levels above --run)')
    args = parser.parse_args()
    saves = Path(os.environ.get('LOL2_CHAIN_SAVES', ''))
    if not saves.is_dir(): sys.exit('Set LOL2_CHAIN_SAVES to the profile tests directory')
    receipts = saves / 'dark_halls_earned'
    profile = saves.parent
    checks, errors = [], []
    def check(ok, text):
        (checks if ok else errors).append(text)
        return ok
    if args.run:
        lines = (Path(args.run) / 'chain.out').read_text().splitlines()
        events = [re.match(r'\[\d\d:\d\d:\d\d\] (\S+) (start|exit=(-?\d+))$', l) for l in lines]
        seq = [(m.group(1), m.group(2)) for m in events if m]
        expected = []
        for leg in LEGS: expected += [(leg, 'start'), (leg, 'exit=0')]
        check(seq == expected, 'chain receipts: 14 legs started/exited 0 once each, in order')
        check(lines[-1].endswith('DARK HALLS DETOUR CHAIN COMPLETE'), 'chain completion line')
    phases = {}
    for name in ['enter', 'finish', 'depart', 'resume']:
        path = receipts / f'{name}.json'
        if not check(path.exists(), f'{name} receipt present'): continue
        phases[name] = json.loads(path.read_text())
        check(phases[name].get('passed') is True, f'{name} receipt passed')
    if len(phases) != 4:
        return finish(args, checks, errors, {})
    e, f, d, r = phases['enter'], phases['finish'], phases['depart'], phases['resume']
    if args.run:
        # flatpak run gives every Godot the same sandbox pid, and the chain runner sets no LOL2_SOURCE_COMMIT: process
        # separation comes from the runner's own receipts (one subprocess per leg, each with its own log and PASS line),
        # and the source from the clone's git (--project).
        legs = {'enter': '11_dark_halls_enter', 'finish': '12_dark_halls_finish', 'depart': '13_dark_halls_depart', 'resume': '14_dark_halls_resume'}
        for name, leg in legs.items():
            text = (Path(args.run) / f'{leg}.log').read_text(errors='replace')
            check(f'PASS dark_halls_earned_detour[{name}]' in text and f'--phase={name}' in text.splitlines()[0], f'{leg}: its own process log with the {name} PASS line')
        project = Path(args.project or Path(args.run).resolve().parents[2])
        import subprocess
        head = subprocess.run(['git', '-C', str(project), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
        dirty = [l for l in subprocess.run(['git', '-C', str(project), 'status', '--porcelain', '--untracked-files=no'], capture_output=True, text=True).stdout.splitlines()]
        # Earlier legs rewrite their own docs/*-checks.json proofs; nothing else may differ from the commit.
        other = [l for l in dirty if l != ' M project.godot' and not (l.startswith(' M docs/') and l.endswith('-checks.json'))]
        user_dir = subprocess.run(['git', '-C', str(project), 'diff', '--unified=0', '--', 'project.godot'], capture_output=True, text=True).stdout
        changed = [l for l in user_dir.splitlines() if l[:1] in '+-' and not l.startswith(('+++', '---'))]
        check(bool(head) and not other and all('custom_user_dir_name' in l for l in changed), f'campaign source {head}: only leg proofs ({len(dirty) - 1}) and the private user-dir line differ')
        e['source_commit'] = head
    else:
        check(len({e['pid'], f['pid'], d['pid'], r['pid']}) == 4, 'four distinct OS processes (host pids)')
        check(e.get('source_commit') and e['source_commit'] == f['source_commit'] == d['source_commit'] == r['source_commit'], 'one source commit for all phases')
    monastery = saves / 'act1_broken_repaired_monastery.json'
    check(e['input']['sha256'] == sha(monastery), 'enter input = earned repaired-monastery save bytes')
    proof = Path(args.project or (Path(args.run).resolve().parents[2] if args.run else Path(__file__).resolve().parents[1])) / 'docs/broken-repair-earned-walk-checks.json'
    if args.run and proof.exists():
        check(json.loads(proof.read_text()).get('output_sha256') == e['input']['sha256'], 'enter input = leg 10 proof output_sha256')
    copies = {'enter': receipts / 'enter_output_quicksave.json', 'finish': receipts / 'finish_output_jungle_quicksave.json',
              'depart': receipts / 'depart_output_darker_arrival.json'}
    for name, copy in copies.items():
        check(copy.exists() and sha(copy) == phases[name]['output']['sha256'], f'{name} kept output copy matches its receipt hash')
    check(e['output']['sha256'] == f['input']['sha256'], 'finish resumed the enter F5 Dark Halls save (hash link)')
    check(f['output']['sha256'] == d['input']['sha256'], 'depart resumed the finish F5 Jungle save (hash link)')
    f5 = receipts / 'depart_darker_f5_quicksave.json'
    check(f5.exists() and sha(f5) == d.get('darker_f5', {}).get('sha256') == r['input']['sha256'], 'resume reopened the depart F5 darker-jungle save (hash link)')
    check(r['output']['sha256'] == r['input']['sha256'], 'resume left the darker F5 save unchanged')
    check(r['after']['dark_halls_windows']['done'] is True and len(r['after']['items']) == len(d['after']['items']), 'resumed darker jungle: puzzle done, item count kept')
    live_darker = saves / 'act1_dark_halls_darker_arrival.json'
    check(live_darker.exists() and sha(live_darker) == d['output']['sha256'], 'darker-jungle save on disk = depart output')
    earned = json.loads(monastery.read_text())
    dh = json.loads(copies['enter'].read_text())
    jungle = json.loads(copies['finish'].read_text())
    darker = json.loads(copies['depart'].read_text())
    soul0 = int(earned['quests']['monastery']['globals']['GV_LUTHERS_SOUL'])
    items0 = earned['inventory']['collected']
    loot = [g for row in e.get('loot', []) for g in row['taken']]
    check(dh['format'] == 'lol2-restoration-dark-halls' and jungle['format'] == 'lol2-restoration-jungle' and darker['format'] == 'lol2-restoration-darker-jungle', 'save formats (Dark Halls, Jungle, darker jungle)')
    w = dh['quests']['dark_halls_windows']
    check(w['opened'] == WINDOWS_FIRST and w['done'] is False, 'Dark Halls save: six windows by E, puzzle open')
    check(int(dh['quests']['monastery']['globals']['GV_LUTHERS_SOUL']) == soul0, 'Dark Halls save: soul unchanged before the seventh window')
    for label, state in [('Jungle', jungle), ('darker', darker)]:
        w = state['quests']['dark_halls_windows']
        check(w['opened'] == WINDOWS_FIRST + [WINDOW_LAST] and w['done'] is True, f'{label} save: seven windows, puzzle done')
        g = state['quests']['monastery']['globals']
        check(int(g['GV_LUTHERS_SOUL']) == soul0 + 1, f'{label} save: soul {soul0} -> {soul0 + 1} (window reward once)')
        check(float(g.get('GV_RIX_DEAD', 0)) == 0 and not state['quests'].get('dark_halls_rix', {}).get('dead', False), f'{label} save: Rix not killed')
        collected = state['inventory']['collected']
        check(all(i in collected for i in items0), f'{label} save: every earned item kept')
        check(len(loot) == 3 and all(i in collected for i in loot) and len(collected) == len(items0) + len(loot), f'{label} save: the three loot grants taken by E and nothing else added')
        check(state['inventory']['equipped_item'] == earned['inventory']['equipped_item'], f'{label} save: equipped weapon kept')
    check(darker['quests']['act_one_departure']['phase'] in ('arrived', 'idle') and int(darker['quests']['act_one_departure']['local55']) == 1, 'darker save: departure movie played (local55 = 1)')
    pop = jungle['quests']['dark_halls_population']['actors']
    killed = sorted(int(k) for k, a in pop.items() if int(a['health']) == 0)
    shades = list(range(58, 76))
    rats_killed = [k for k in killed if 25 <= k <= 55]
    check(len(rats_killed) > 0 and all(k in killed for k in shades), f'population: {len(rats_killed)} Rats killed in combat; grid Shades 58-75 at 0 (hosted simplified orb end, not native)')
    combat = [c for c in e.get('combat', []) + f.get('combat', []) if 'actor' in c]
    check(len(combat) > 0, f'combat engagements recorded: {len(combat)}')
    check(int(e['walk']['resets']) == 0, 'no fall resets on the Dark Halls walk')
    summary = {'soul': [soul0, soul0 + 1], 'items_before': len(items0), 'loot': loot, 'rats_killed': rats_killed,
               'engagements': len(combat), 'heals': sum(1 for c in e.get('combat', []) + f.get('combat', []) if 'heal' in c),
               'min_health': min([h[1] for h in e.get('health', []) + f.get('health', [])] or [None]),
               'hashes': {'monastery_input': e['input']['sha256'], 'dark_halls_arrival_f5': e.get('arrival_save', {}).get('sha256'),
                          'dark_halls_f5': e['output']['sha256'], 'jungle_f5': f['output']['sha256'], 'darker_save': d['output']['sha256'], 'darker_f5': d.get('darker_f5', {}).get('sha256')},
               'pids': [e['pid'], f['pid'], d['pid'], r['pid']], 'source_commit': e['source_commit']}
    return finish(args, checks, errors, summary)

def finish(args, checks, errors, summary):
    result = {'passed': not errors, 'checks': checks, 'errors': errors, 'summary': summary}
    if args.json: Path(args.json).write_text(json.dumps(result, indent=2) + '\n')
    for c in checks: print('ok  ', c)
    for c in errors: print('FAIL', c)
    print('PASS earned Dark Halls detour chain' if not errors else f'FAIL {len(errors)} checks')
    return 0 if not errors else 1

if __name__ == '__main__':
    sys.exit(main())
