#!/usr/bin/env python3
"""Audit fresh rendered receipts separately from historical save continuity."""
import argparse
import datetime as dt
import json
import re
from pathlib import Path
from zoneinfo import ZoneInfo
from audit_broken_sword_chain import ROOT, SAVES, ROWS, digest
from regression_source import snapshot, changes

NAMES = ['01_cave', '02_museum', '03_jungle_hive', '04_flute', '05_wax',
         '06_runes', '07_rune_return', '08_knowledge', '09_translation',
         '10_repair', '11_departure']



def check_contents(index, state, require_kityara=False):
    """Carry forward the established broken-sword branch acceptance checks."""
    inventory = state['checkpoint']['collected'] if index == 0 else state['inventory']['collected']
    for item in ['cave:captain:Short_Sword', 'cave:captain:Burnt_Chain']:
        assert inventory.count(item) == 1, 'Earned captain reward missing or duplicated: ' + item
    if index == 0:
        return ['Both earned captain rewards retained at Museum arrival']
    items, quests = state['inventory']['collected'], state['quests']
    assert items.count('cave:prop641:harvest1:Stalagmite') == 1, 'Earned cave weapon missing or duplicated'
    assert items.count('museum:item11:Fine_Longsword') == 1, 'Museum sword missing or duplicated'
    assert quests['museum_control181'] == {'owner_state': 1, 'sprite_mode': 1}, 'Broken-sword exhibit history differs'
    if index >= 9:
        assert items.count('jungle:magic_shop:Tho_fixed') == 1, 'Repaired sword missing or duplicated'
        assert 'museum:control181:Tho_Broken' not in items, 'Broken sword not consumed'
        assert 'monastery:item83:Power_Orb' not in items, 'Repair orb not consumed'
    else:
        assert items.count('museum:control181:Tho_Broken') == 1, 'Earned broken sword missing or duplicated'
    checks = ['Both earned captain rewards retained', 'Cave weapon retained', 'Museum sword retained', 'Broken-sword branch inventory and exhibit history']
    if require_kityara and index >= 7:
        shop = quests['weapon_shop']
        assert shop['locals'].get('Met_Kityara') == 1, 'Kityara first meeting not earned'
        assert shop['globals'].get('GV_LUTHER_KNOWS_ABOUT_DANIEL') == 1, 'Shop introduction not completed'
        checks.append('Earned Kityara shop entry and Daniel introduction retained')
        if index >= 9:
            assert shop['locals'].get('kityara_gave_knife') == 1, 'Kityara knife follow-up not completed'
            assert quests['monastery']['globals'].get('GV_LUTHER_HAS_WARBLADE') == 1, 'Kityara clip completion flag missing'
            assert items.count('jungle:kityara:Empty_hand') == 1, 'Kityara original grant missing or duplicated'
            checks.append('Kityara knife, original completion flag and one-time grant retained')

    if index == 10:
        assert state['format'] == 'lol2-restoration-darker-jungle', 'Wrong destination save format'
        assert quests['act_one_departure']['phase'] == 'arrived', 'Departure not complete'
        assert quests['magic_shop']['flags']['49'] == 1, 'Repair exchange flag absent'
        assert quests['monastery']['globals']['GV_RUNES_TRANSLATED'] == 1, 'Runes not translated'
        assert quests['monastery']['globals']['GV_LUTHERS_SOUL'] == 7, 'Soul state differs (initial5 + Julian1 + repair1)'
        for flag in ['148', '288', '259']:
            assert quests['monastery']['flags'][flag] == 1, f'Monastery flag {flag} absent'
        checks.append('Darker-jungle arrival, translation, orb, blessing and repair flags')
    return checks


def audit(run, baseline, day, require_kityara=False):
    receipts = (run / 'chain.out').read_text()
    source = json.loads(baseline.read_text())
    drift = changes(source['source_end'], snapshot(ROOT))
    legs, previous, prefix = [], None, 0
    continuous = True
    for name, (proof_name, save_name) in zip(NAMES, ROWS):
        starts = re.findall(r'\[(\d\d:\d\d:\d\d)\] ' + name + r' start', receipts)
        exits = re.findall(r'\[\d\d:\d\d:\d\d\] ' + name + r' exit=(\d+)', receipts)
        row = dict(name=name, status='not_started', errors=[])
        proof, save, log = ROOT/'docs'/f'{proof_name}.json', SAVES/f'{save_name}.json', run/f'{name}.log'
        if starts:
            row['status'] = 'running' if not exits else 'failed'
            # Reject resumed/repeated logs: receipts must identify a single fresh run.
            if len(starts) != 1 or len(exits) > 1:
                row['errors'].append('Ambiguous repeated receipt; use a new run directory')
            if exits:
                row['exit_code'] = int(exits[-1])
                if row['exit_code']:
                    row['errors'].append('Driver did not exit successfully')
                try:
                    text = log.read_text()
                    if 'PASS' not in text or re.search(r'^(?:SCRIPT )?ERROR:', text, re.M):
                        row['errors'].append('Log lacks PASS or contains engine/script errors')
                    data = json.loads(proof.read_text())
                    actual = digest(save)
                    state = json.loads(save.read_text())
                    assert isinstance(state, dict), 'Save is not an object'
                    assert data.get('passed') is True, 'Proof does not pass'
                    assert data.get('output_sha256', data.get('output_checkpoint_sha256')) == actual, 'Output hash differs'
                    if name != NAMES[0]:
                        assert previous and data.get('input_sha256') == previous, 'Previous actual save does not link'
                    start = dt.datetime.fromisoformat(f'{day}T{starts[0]}').replace(tzinfo=ZoneInfo('Europe/Berlin')).timestamp()
                    assert proof.stat().st_mtime >= start and save.stat().st_mtime >= start, 'Proof/save predates fresh leg'
                    row['content_checks'] = check_contents(NAMES.index(name), state, require_kityara)
                    row.update(proof_sha256=digest(proof), output_sha256=actual, log_sha256=digest(log))
                    previous = actual
                except (OSError, ValueError, KeyError, TypeError, AssertionError) as error:
                    row['errors'].append(str(error))
                    previous = None
                if not row['errors']:
                    row['status'] = 'verified'
        continuous = continuous and row['status'] == 'verified'
        prefix += int(continuous)
        legs.append(row)
    first = re.search(r'\[(\d\d:\d\d:\d\d)\] 01_cave start', receipts)
    baseline_ok = (source.get('complete') is True and source.get('passed') is True
                   and source.get('source_stable') is True and first is not None)
    if first:
        started = dt.datetime.fromisoformat(f'{day}T{first[1]}').replace(tzinfo=ZoneInfo('Europe/Berlin')).timestamp()
        baseline_ok = baseline_ok and baseline.stat().st_mtime <= started
    return dict(verified_fresh_prefix=prefix, total_legs=len(legs),
                complete=prefix == len(legs) and baseline_ok and not drift and 'CHAIN COMPLETE' in receipts,
                source_baseline=str(baseline.relative_to(ROOT)), source_changed_files=drift,
                baseline_verified=baseline_ok, kityara_required=require_kityara,
                checked_utc=dt.datetime.now(dt.timezone.utc).isoformat(), legs=legs,
                scope='Fresh single-day Europe/Berlin receipts, clean PASS logs, proof/save timestamps, actual linked hashes, branch inventory/quest checks and source endpoint comparison. Media excluded. Endpoint equality cannot exclude intervening edits. Content completeness, rendering quality and original-game parity require separate acceptance.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--date', required=True, help='Receipt date YYYY-MM-DD, Europe/Berlin; one-day runs only')
    parser.add_argument('--run', type=Path, default=ROOT/'tmp/regressions/broken_chain_fresh')
    parser.add_argument('--baseline', type=Path, default=ROOT/'tmp/regressions/aura_area_fix/report.json')
    parser.add_argument('--require-kityara', action='store_true', help='Require earned shop meeting, knife follow-up and retained grant')
    args = parser.parse_args()
    dt.date.fromisoformat(args.date)
    report = audit(args.run.resolve(), args.baseline.resolve(), args.date, args.require_kityara)
    (ROOT/'docs/fresh-rendered-chain-progress.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f"Verified fresh prefix {report['verified_fresh_prefix']}/{report['total_legs']}; source changes {len(report['source_changed_files'])}; complete={report['complete']}")
    for leg in report['legs']:
        if leg['status'] != 'not_started': print(leg['name'], leg['status'], '; '.join(leg['errors']))


if __name__ == '__main__':
    main()
