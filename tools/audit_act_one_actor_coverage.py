#!/usr/bin/env python3
"""Join pinned source placements to explicitly reviewed live actor evidence.

Unmatched placements require classification; they are not automatically enemies,
mandatory encounters, or proof of missing gameplay.
"""
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
AREAS = ('L1_DC', 'L3_DH', 'L4_HJ', 'L5_HC')
# Positive bindings only. Other scripted/rendered actors remain unclassified here.
BINDINGS = {
    ('L1_DC', 24): ('scripts/lol2/cave_eyes.gd', 'cave_eyes_state.gd', 'source eyes, aimed use, original33frames/sound, path1 and timed removal; saved rendered fixture; movement/presentation scheduling adapters'),
    ('L1_DC', 55): ('scripts/lol2/cave_scenic_guard.gd', 'cave_scenic_guard_state.gd', 'source scenic guard rendering and saved region969 alternative removal; hit/explosion branch and environmental suffix still open'),
    ('L1_DC', 0): ('scripts/lol2/cave_wild_roach.gd', 'cave_wild_roach_source.json', 'source-present Roach; live aimed melee/Spark, audio, rewards and atomic save rollback; native behavior6 scheduling is a modern pursuit adapter'),
    ('L1_DC', 23): ('scripts/lol2/cave_roach.gd', 'OriginalRoach23', 'live encounter; authored combat tuning'),
    ('L5_HC', 32): ('scripts/lol2/hive_warriors.gd', 'const ACTORS := [32,34]', 'stationary guardian; authored health/timing'),
    ('L5_HC', 34): ('scripts/lol2/hive_warriors.gd', 'const ACTORS := [32,34]', 'stationary guardian; authored health/timing'),
    ('L5_HC', 33): ('scripts/lol2/hive_ambush.gd', 'hive_ambush_state.gd', 'source-region unfolding film and live combat; adapter scheduling/presentation'),
    ('L5_HC', 35): ('scripts/lol2/hive_ambush.gd', 'hive_ambush_state.gd', 'source-region feeding-to-attack films and live combat; alternate hit path still open'),
    ('L5_HC', 36): ('scripts/lol2/hive_executioner_live.gd', 'receive_strike', 'live Executioner; source rewards, adapter navigation/damage'),
}
for actor in [30,31]:
    BINDINGS[('L5_HC',actor)] = ('scripts/lol2/hive_boulders.gd','State.SPAWNS','partial rolling-boulder presentation/path/save integration; motion/scheduler/audio-mixing/contact-geometry/health adapters; live contact damage and saved impulse')
for actor in range(23,30):
    BINDINGS[('L5_HC',actor)] = ('scripts/lol2/hive_return_population.gd','rules.SPAWNS','return-warrior pool; source positions/health/rewards, adapter arrival/movement/attacks')
for actor in [21,22]:
    BINDINGS[('L5_HC',actor)] = ('scripts/lol2/hive_rune_population_state.gd','TEMPLATES=', 'template copied into finite restored slots; local combat/save headless integration, rendered admission still pending; partial pool/clock/loot adapters')
for actor in [36,37]:
    BINDINGS[('L1_DC',actor)] = ('scripts/lol2/cave_lurking_roach.gd','cave_lurking_roach_source.json','source-present WORM pair; startup event9 op13 sub16 marker59 retained; native-bound AA1 chase/AA2 reach attack clip5, live aimed melee/Spark rewards, original corpse/audio and atomic save rollback; native goal5/goal6 wander scoring and condition production remain adapters')
for actor in list(range(25,36))+list(range(40,52)):
    BINDINGS[('L1_DC',actor)] = ('scripts/lol2/cave_roach_population.gd','cave_population_actor','source-position population with pursuit/bite, melee/Spark rewards and saved movement; earned cave route passes; native scheduling, audio and loot remain open')
# Data-driven populations are checked against their source identities below.
POPULATIONS = [
    ('L4_HJ', 'jungle_bacatta65', 'scripts/lol2/jungle_bacatta65.gd', 'jungle_bacatta65_population_source.json',
     'alert-before-first-meeting trigger, original conversation/media, idle offer/walk-away/hit, peaceful/hostile body, pause and disk persistence; independent actual damage and corpse check passes; supplied approach, modern combat/timing and no Bob acceptance'),
    ('L5_HC', 'hive_dawn20', 'scripts/lol2/hive_dawn20.gd', 'hive_dawn20_population_source.json',
     'alternate translation after library attack, queued RUNES admission, dialogue/offers/hit, saved body and removal on re-entry; eight focused checks pass; hostile attacks, region478 unload and kind5 producer remain open'),
    ('L4_HJ', 'jungle_exit_woman', 'scripts/lol2/jungle_exit_woman.gd', 'jungle_exit_woman_population_source.json',
     'prop554 conversations and L4WW0/66 body links, local earned approach, saved hold/focus/voice, repeated-load callback guards and home-walk/removal integrated; seven focused checks PASS; sighting/hit, speed/path/arrival extent are adapters; full campaign and GPU/audio acceptance remain open'),
    ('L4_HJ', 'jungle_bacatta', 'scripts/lol2/jungle_bacatta.gd', 'jungle_bacatta_population_source.json',
     'Bacatta61 prop552 conversation/approach/guard60/exit branch with original media and saved generic body; focused rendered fixture passes; hostile clips/outcomes and native timing remain partial'),
    ('L4_HJ', 'jungle_exit_guard', 'scripts/lol2/jungle_exit_encounter.gd', 'jungle_exit_guard_population_source.json',
     'guards58-60 source phase/presence/health/defeat and original pose/ending media with generic bodies; focused rendered checks pass; visibility-trigger admission and callback timing are adapters, complete earned branches remain open'),
    ('L4_HJ', 'jungle_kelsrick', 'scripts/lol2/jungle_kelsrick.gd', 'jungle_kelsrick_population_source.json',
     'source dialogue/held-item/hostile branch on production host; fresh rendered fixture and atomic save checks; external event consumers and earned approach remain open'),
    ('L4_HJ', 'jungle_dawn', 'scripts/lol2/jungle_dawn.gd', 'jungle_dawn_population_source.json',
     'source sight/talk/rune offer/reward/hostile transition on production host; fresh rendered fixture and atomic save checks; hostile spell effects, transformation admission and external event consumers remain open'),
    ('L4_HJ', 'jungle_actor62', 'scripts/lol2/jungle_actor62.gd', 'jungle_actor62_population_source.json',
     'four original lines and action2 completion to state11; fresh production-host rendered fixture/save checks; peaceful wandering and earned approach remain open'),
    ('L1_DC', 'cave_guard', 'scripts/lol2/cave_walkthrough.gd', 'GUARD_CONFIG',
     'eight guards on shared owner; region spawn/wake, combat/save/audio and guard controls integrated; general loot and native scheduling remain open'),
    ('L3_DH', 'museum_skeleton', 'scripts/lol2/museum_skeleton_population.gd', 'MUSEUM_CONFIG',
     'skeletons/Rat on shared owner with combat/save/audio; control96/loot and complete encounter acceptance remain open'),
    ('L4_HJ', 'jungle_dino', 'scripts/lol2/jungle_dino_population.gd', 'jungle_dino_population_state.gd',
     'DINO pursuit/bite, combat/save/audio and idle; native movement/cadence and full earned campaign remain open'),
    ('L4_HJ', 'jungle_villager', 'scripts/lol2/jungle_walkthrough.gd', 'VILLAGER_CONFIG',
     'villagers bound to shared owner; idle/provocation/save adapter; native wandering and rendered acceptance remain open'),
]
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    source = ROOT / 'docs/game-actors.json'
    original = json.loads(source.read_text())
    staging_path = ROOT / "docs/act-one-actor-staging.json"
    staging = json.loads(staging_path.read_text())
    assert staging["source_inventory_sha256"] == sha(source)
    staging_ids = {(row["area"], row["actor"]) for row in staging["actors"]}
    assert len(staging_ids) == len(staging["actors"]) == 80
    unactivated_path = ROOT / "docs/act-one-actor-unactivated.json"
    unactivated = json.loads(unactivated_path.read_text())
    assert unactivated["source"]["geometry_sha256"] == next(a for a in original["areas"] if a["id"] == "L4_HJ")["source"]["geometry_sha256"]
    unactivated_ids = {(row["area"], row["actor"]) for row in unactivated["actors"]}
    assert len(unactivated_ids) == len(unactivated["actors"]) == 3
    assert unactivated_ids == {("L4_HJ", actor) for actor in (36,37,38)}
    assert not unactivated_ids & staging_ids
    bindings = {}
    population_contracts = {}
    reviewed = dict(BINDINGS)
    for area, prefix, owner, anchor, scope in POPULATIONS:
        name = 'scripts/lol2/' + prefix + '_population_source.json'
        contract = json.loads((ROOT / name).read_text())
        ids = [row['actor'] for row in contract['actors']]
        assert len(ids) == len(set(ids)), name
        population_contracts[name] = dict(sha256=sha(ROOT / name), actors=ids)
        for actor in ids:
            key = (area, actor)
            assert key not in reviewed, key
            reviewed[key] = (owner, anchor, scope)
    for key, (name, anchor, scope) in reviewed.items():
        path = ROOT / name
        assert anchor in path.read_text(), (key, name, anchor)
        if key == ("L1_DC", 56):
            scope = "captain introduction, source surrender and both reward grants integrated; earned full cave-to-Museum save retains rewards; generic pursuit/combat and presentation timing remain adapters"
        bindings[key] = dict(path=name, sha256=sha(path), scope=scope)
    areas = []
    for area in original['areas']:
        if area['id'] not in AREAS:
            continue
        rows = []
        seen = set()
        for definition in area['definitions']:
            for actor in definition['actors']:
                assert actor not in seen
                seen.add(actor)
            positive = {str(actor): bindings[(area['id'], actor)] for actor in definition['actors'] if (area['id'], actor) in bindings}
            inert = [actor for actor in definition['actors'] if (area['id'], actor) in staging_ids]
            assert not set(inert) & set(map(int, positive)), 'staging cannot also be a live binding'
            dormant = [actor for actor in definition['actors'] if (area['id'], actor) in unactivated_ids]
            assert not set(dormant) & set(map(int, positive)), 'unactivated cannot also be a live binding'
            unresolved = [actor for actor in definition['actors'] if str(actor) not in positive and actor not in inert and actor not in dormant]
            rows.append(dict(definition=definition['definition'], name=definition['name'], actors=definition['actors'], reviewed_live_bindings=positive, inert_staging_at_load=inert, unactivated_by_direct_scripts=dormant, classification_pending=unresolved))
        areas.append(dict(id=area['id'], source=area['source'], placement_count=len(seen), definitions=rows))
    matched = {(a['id'], int(actor)) for a in areas for row in a['definitions'] for actor in row['reviewed_live_bindings']}
    assert matched == set(bindings), ('unmatched implementation identities', set(bindings) - matched)
    assert set(a['id'] for a in areas) == set(AREAS)
    classified = {(a['id'], actor) for a in areas for row in a['definitions'] for actor in row['inert_staging_at_load']}
    assert classified == staging_ids, 'staging identity absent from original inventory'
    dormant_matched = {(a['id'], actor) for a in areas for row in a['definitions'] for actor in row['unactivated_by_direct_scripts']}
    assert dormant_matched == unactivated_ids, 'unactivated identity absent from original inventory'
    total = sum(a['placement_count'] for a in areas)
    report = dict(source_inventory_sha256=sha(source), scope='Four pre-departure map archives only. Positive implementation bindings are reviewed leads, not completion. Unmatched actors may be alternate states, script placeholders, cinematic actors or playable encounters; source reachability and live implementation classification remain required. L8_SJ acceptance ends at verified arrival/onward walk, not completion of Act Two content.', placement_count=total, reviewed_live_bindings=len(bindings), inert_staging_at_load=len(staging_ids), staging_evidence=dict(path='docs/act-one-actor-staging.json', sha256=sha(staging_path), scope=staging['scope']), unactivated_by_direct_scripts=len(unactivated_ids), unactivated_evidence=dict(path='docs/act-one-actor-unactivated.json', sha256=sha(unactivated_path), scope=unactivated['scope']), population_contracts=population_contracts, areas=areas)
    (ROOT/'docs/act-one-actor-coverage.json').write_text(json.dumps(report, indent=2)+'\n')
    lines = ['# Act One actor coverage audit', '', report['scope'], '', f'{total} source placements across four archives; {len(bindings)} explicitly reviewed implementation bindings (including partial actors). These numbers are not a completion percentage.', '', '| Area | Definition / label | Source actors | Reviewed live actors | Inert staging at load | Unactivated by direct scripts | Classification pending |', '| --- | --- | --- | --- | --- | --- | --- |']
    for area in areas:
        for row in area['definitions']:
            ids = lambda values: ', '.join(map(str,values)) or 'none'
            lines.append(f"| {area['id']} | {row['definition']} / {row['name']} | {ids(row['actors'])} | {ids(row['reviewed_live_bindings'])} | {ids(row['inert_staging_at_load'])} | {ids(row['unactivated_by_direct_scripts'])} | {ids(row['classification_pending'])} |")
    lines += ['', '80 blank placements are classified as inert staging at load by independently checked native constructor/update evidence: [classification](act-one-actor-staging.json). Computed-target linking is not ruled out. This classification adds no live gameplay coverage. TIG_ROG 36-38 are absent at load with no direct link command or own event list: [evidence](act-one-actor-unactivated.json); computed-target linking is not ruled out and no gameplay is claimed. Two concrete actors remain unbound.', '', 'Reproduce with `python3 tools/audit_act_one_actor_coverage.py`. The JSON pins the source inventory, numeric population contracts and reviewed implementation hashes. Every population identity must exist in the original inventory; duplicates and unmatched bindings fail. This checks structural bindings, not executed encounters or full acceptance.', '', 'Current remaining work: resolve unimplemented loot/treasure producers and hostile story branches; classify the remaining unmatched actor before treating them as encounters; retain the indirect-activation caveat for inert staging; complete a fresh continuous campaign with current encounter state. Museum control96 and sword skeleton21, cave guard controls and captain reward are integrated; their original scheduling and remaining branches still require scoped acceptance. Roach pursuit/bites and melee progression are implemented; guard/Museum/DINO audio has focused save/pause validation. Villagers have a shared-owner binding but native wandering and rendered acceptance remain open. Original scheduling/presentation and adapter limits remain documented in each encounter report.']
    (ROOT/'docs/act-one-actor-coverage.md').write_text('\n'.join(lines)+'\n')
    print(f'PASS inventory join: {total} placements, {len(bindings)} reviewed live encounter bindings; other classification OPEN')
if __name__ == '__main__':
    main()
