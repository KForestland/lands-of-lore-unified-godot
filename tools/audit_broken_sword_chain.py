#!/usr/bin/env python3
"""Require actual linked saves for the earned Museum sword -> Rashar repair branch."""
import datetime
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SAVES = Path('/home/bob/.var/app/org.godotengine.Godot/data/godot/app_userdata/Lands of Lore Unified Godot/tests')
ROWS = [
 ('cave-starting-spells-walk-checks','act1_magic_museum_arrival'),
 ('museum-broken-sword-earned-checks','act1_broken_museum_jungle'),
 ('broken-earned-jungle-hive-walk-checks','act1_broken_hive_entry'),
 ('broken-earned-flute-return-walk-checks','act1_broken_flute_hive_return'),
 ('broken-hive-wax-return-checks','act1_broken_wax_upper_return'),
 ('broken-hive-earned-rune-walk-checks','act1_broken_earned_runes'),
 ('broken-hive-earned-rune-return-checks','act1_broken_runes_monastery_return'),
 ('broken-magic-knowledge-walk-checks','act1_broken_orb_monastery'),
 ('broken-monastery-rune-offer-live-checks','act1_broken_runes_translated'),
 ('broken-repair-earned-walk-checks','act1_broken_repaired_monastery'),
 ('broken-act-one-departure-full-walk-checks','act1_broken_earned_darker_arrival'),
]
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    previous = None
    legs = []
    for index, (proof_name, save_name) in enumerate(ROWS):
        proof = ROOT / 'docs' / (proof_name + '.json')
        save = SAVES / (save_name + '.json')
        data = json.loads(proof.read_text())
        assert data['passed'], proof
        if previous:
            assert data['input_sha256'] == previous, proof
        actual = digest(save)
        assert data.get('output_sha256', data.get('output_checkpoint_sha256')) == actual, save
        state = json.loads(save.read_text())
        if index >= 1:
            items = state['inventory']['collected']
            quests = state['quests']
            if index >= 9:
                assert items.count('jungle:magic_shop:Tho_fixed') == 1, save
                assert 'museum:control181:Tho_Broken' not in items and 'monastery:item83:Power_Orb' not in items, save
            else:
                assert items.count('museum:control181:Tho_Broken') == 1, save
            assert quests['museum_control181'] == {'owner_state':1,'sprite_mode':1}, save
        legs.append(dict(proof=str(proof.relative_to(ROOT)),proof_sha256=digest(proof),output_save=save.name,output_sha256=actual))
        previous = actual
    final = json.loads((SAVES / 'act1_broken_earned_darker_arrival.json').read_text())
    assert final['quests']['act_one_departure']['phase'] == 'arrived'
    assert final['quests']['magic_shop']['flags']['49'] == 1
    assert final['quests']['monastery']['globals']['GV_RUNES_TRANSLATED'] == 1
    assert final['quests']['monastery']['globals']['GV_LUTHERS_SOUL'] == 2
    for flag in ['148','288','259']:
        assert final['quests']['monastery']['flags'][flag] == 1
    result = dict(passed=True,checked_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),legs=legs,
        scope='Eleven actual save links from cave start to Museum broken sword, Hive rescue/flute/wax/runes, Rashar knowledge, Julian translation/orb, Morgan blessing, Rashar repair and darker-jungle arrival. Cave leg reused; downstream legs rerun. Automated steering, accelerated time/audio and manually driven movement/curse ticks; no new position/inventory/quest injection. Full content, fresh complete campaign and owner acceptance remain open.')
    (ROOT / 'docs/broken-sword-earned-chain-checks.json').write_text(json.dumps(result,indent=2)+'\n')
    print('PASS eleven actual save links with earned broken sword, orb repair and darker-jungle arrival')
if __name__ == '__main__': main()
