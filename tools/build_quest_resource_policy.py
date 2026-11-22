#!/usr/bin/env python3
"""Compile source-derived quest obligations with the audited finite solver.

This is a protection policy for the hosted main road, not a whole-game
unwinnability certificate. Exact recipes stay exact. Counts are solver outputs,
not designer-selected reserves. Changing a cited owner invalidates --check.
"""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
from quest_resource_model import Rule, reserve_frontier
from quest_resource_schema import initial as owner_initial, literal, resolve, returned_dictionary

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'scripts/lol2/quest_resource_policy.json'
PROVIDER = ROOT / 'scripts/lol2/quest_resource_policy_data.gd'


def build(root=ROOT):
    pins, obligations = {}, []

    def constant(file, name):
        path = root / 'scripts/lol2' / file
        pins[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
        match = re.search(r'^const ' + name + r'\s*(?::=|=)\s*(.+)$', path.read_text(), re.M)
        if not match:
            raise ValueError(f'Missing literal recipe constant: {file}:{name}')
        return literal(match[1], path)

    def add(name, items, done, reason, *, definitions=False, slots=None, recoverable=None, target_ids=None):
        # Each source recipe target is a distinct goal atom. Interchangeable
        # item identities are alternatives; sequential reuse is NOT addition.
        targets = list(target_ids) if target_ids is not None else list(items)
        if not targets or len(set(targets)) != len(targets):raise ValueError("Missing/duplicate source goal targets: "+name)
        held = {f'held:{i}': 'resource' for i in range(len(items))}
        rules = [Rule(f'offer:{i}:{j}', frozenset([f'held:{i}']), frozenset([f'done:{j}']),
                      frozenset([f'held:{i}'])) for i in range(len(items)) for j in targets]
        frontier = reserve_frontier(set(held), rules, {f'done:{j}' for j in targets}, held)
        if not frontier.get('alternatives'):
            raise ValueError(f'No qualified reserve: {name}: {frontier}')
        counts = {a['counts']['resource'] for a in frontier['alternatives']}
        if len(counts) != 1:
            raise ValueError('Nonuniform minimum needs an alternative policy')
        obligations.append({'name': name, 'items': items, 'definitions': definitions,
                            'need': counts.pop(), 'goal_targets':targets, 'done': done, 'reason': reason,
                            'slots': slots or [], 'recoverable': recoverable or [],
                            'model_frontier': frontier['alternatives']})

    def truth(*path): return {'path': list(path), 'truthy': True}
    def receipt(key, target): return truth(key, 'slots', target, 'committed')

    ingredients = constant('l14_priest_ritual.gd', 'INGREDIENTS')
    ritual = constant('l14_priest_ritual.gd', 'KEY')
    for bowl, item in ingredients.items():
        add('Temple offering ' + bowl, [item], [receipt(ritual, bowl)],
            'Keep this Poison Paint for the Temple priest\'s ritual.' if bowl == '369'
            else 'Keep this aloe for the Temple priest\'s ritual.', target_ids=[bowl])
    niche = constant('l14_niche.gd', 'KEY')
    add('Temple statue', [constant('l14_niche.gd', 'STATUE')],
        [receipt(niche, constant('l14_niche.gd', 'TARGET'))], 'Keep the statue for the Temple niche.',target_ids=[constant('l14_niche.gd','TARGET')])
    for file, field, name, reason in [
        ('l14_shard_bowls.gd', 'SHARDS', 'Temple shards', 'Keep these shards for the Temple passage.'),
        ('l14_idol_pedestals.gd', 'IDOLS', 'Temple idols', 'Keep the Jkaran idols for the Temple crossing.')]:
        key = constant(file, 'KEY')
        add(name, constant(file, field), [], reason, slots=[key],
            recoverable=[['l8_tree', 'lock']] if field == 'SHARDS' else [],
            target_ids=list(constant(file,'BOWLS' if field=='SHARDS' else 'CASES')))
    key = constant('l14_hopper_platform.gd', 'KEY')
    ids = constant('l14_hopper_platform.gd', 'IDS')
    add('Temple platform', ['act2:L14_HT:hopper_corpse' + i for i in ids], [],
        'Keep the Hopper bodies for the Temple elevator.', slots=[key],target_ids=ids)
    # Flute admission is explicitly a legacy identity OR definition96.
    key = constant('l14_flute_slot.gd', 'KEY')
    target = constant('l14_flute_slot.gd', 'TARGET')
    add('Temple flute', ['monastery:item94:Iron_Flute', 96], [receipt(key, target)],
        'Keep the Iron Flute for the Temple oil passage.', definitions=True,
        target_ids=[target], recoverable=[key, {'path': [constant('hive_flute_floor.gd', 'KEY')], 'area': 'L5_HC'}])
    stone = constant('l13_altar_state.gd', 'STONE')
    add('Citadel altar sword', constant('l13_altar_state.gd', 'SWORDS'),
        [truth(constant('l13_altar_state.gd','KEY'), 'output')], 'Keep a sword for the Ruloi Citadel altar.',
        definitions=True, target_ids=[constant('l13_altar_state.gd','TARGET')])
    add('Dreamstone', [stone, 136], [truth(constant('l14_chamber_voices.gd','KEY'), 'offered')],
        'Keep the Dreamstone for the Chamber of Voices.', definitions=True, target_ids=[constant('l14_chamber_voices.gd','KEY')+':offered'],
        recoverable=['l13_exit_lock', 'l14_spiral', 'l8_temple_door'])
    full = constant('l10_ankh_state.gd', 'FULL')
    ankh = constant('l10_ankh_state.gd', 'ANKH')
    add('Priest ashes', [full], [receipt(constant('l10_ankh_state.gd','KEY'), constant('l10_ankh_state.gd', 'TRADE'))],
        'Keep the ashes to return them to the Cemetery priest.',target_ids=[constant('l10_ankh_state.gd','TRADE')])
    inner = constant('l10_emperor_state.gd', 'INNER')
    add('Emperor ankh', [ankh], [receipt(constant('l10_emperor_state.gd','KEY'), inner)],
        'Keep the ankh for the Emperor\'s tomb.', recoverable=['l10_ankh'],target_ids=[inner])
    weapons = constant('l20_finale.gd', 'WEAPONS')
    add('Belial ending', weapons, [truth(constant('l20_finale.gd','KEY'), 'started')],
        'Keep a Blue Bow, Dark Sword or Belial horn for Belial.', target_ids=[constant('l20_finale.gd','KEY')+':started'])
    bow = constant('l20_armory.gd', 'BLUE_BOW')
    add('Armory fireball', [bow], [truth(constant('l20_armory.gd','KEY'), 'fire')],
        'Keep the Blue Bow for the fireball in Belial\'s fortress.',target_ids=[constant('l20_armory.gd','KEY')+':fire'])
    # The route needs separate leaves for initiation, shaman, mix and pyramid.
    # Already-owned definition119 Serum is the actual rule's alternate source.
    leaf = constant('l16_greenhouse.gd', 'KEY')
    add('City pyramid', [117], [truth(leaf, 'silverleaf')],
        'Keep a Silverleaf for the glass pyramid in the City.', definitions=True,target_ids=[leaf+':silverleaf'])
    leaf_row = obligations[-1]
    tribe = constant('l8_tribe_state.gd', 'KEY')
    tribe_target = constant('l8_tribe_state.gd', 'TARGET')
    trade = constant('l8_shaman_trade.gd', 'KEY')
    trade_target = constant('l8_shaman_trade.gd', 'TARGET')
    serum = constant('l8_shaman_trade.gd', 'SERUM')
    mix = constant('l8_larkhon_state.gd', 'KEY')
    mix_target = constant('l8_larkhon_state.gd', 'SERUM')
    vapors = constant('l8_larkhon_state.gd', 'VAPORS')
    leaf_goals = [tribe_target, trade_target, constant('l8_larkhon_state.gd', 'LEAF'), leaf+':silverleaf']
    profiles = {}
    for profile, targets in [('before_initiation', leaf_goals), ('after_initiation', leaf_goals[1:]),
                             ('with_serum_before_initiation', [leaf_goals[0]]+leaf_goals[2:]), ('with_serum', leaf_goals[2:]), ('after_mix', leaf_goals[3:]), ('complete', [])]:
        held = {f'leaf:{i}': 'silverleaf' for i in range(len(leaf_goals))}
        initial = set(held) | {'story:complete'}
        rules = [Rule(f'use:{i}:{j}', frozenset([f'leaf:{i}']), frozenset([j]),
                      frozenset([f'leaf:{i}'])) for i in range(len(leaf_goals)) for j in targets]
        frontier = reserve_frontier(initial, rules, set(targets) | {'story:complete'}, held)
        amounts = {r['counts'].get('silverleaf', 0) for r in frontier['alternatives']}
        if len(amounts) != 1: raise ValueError('Nonuniform leaf frontier')
        profiles[profile] = {'need': amounts.pop(), 'frontier': frontier['alternatives'], 'goals': targets}
    leaf_row['quantity_profiles'] = profiles
    leaf_row['need'] = profiles['before_initiation']['need']
    leaf_row['model_frontier'] = profiles['before_initiation']['frontier']
    mixer = (root/'scripts/lol2/l8_larkhon_state.gd').read_text()
    serum_def = int(re.search(r'Items.definition\(serum\)\s*!=\s*(\d+)', mixer)[1])
    add('Larkhon Serum', [serum_def], [receipt(mix, mix_target), truth('l13_altar', 'stone_taken'),
        truth('l14_chamber_voices', 'offered')], 'Keep the Amaranth Serum for the Larkhon mixture.', definitions=True,target_ids=[mix_target])
    obligations[-1]['before_larkhon_only'] = True
    serum_row = obligations.pop()
    obligations.insert(obligations.index(leaf_row), serum_row)
    leaf_chain = {'serum_definition': serum_def, 'mix_path': [mix, 'slots', mix_target, 'committed'],
        'tribe_path': [tribe, 'slots', tribe_target, 'committed'],
        'trade_path': [trade, 'slots', trade_target, 'committed'],
        'growth_key': constant('l10_silverleaf.gd', 'KEY'),
        'harvest_key': constant('l10_silverleaf_harvest.gd', 'KEY'),
        'trees': constant('l10_silverleaf.gd', 'TREES'),
        'steps': [
            {'receipt': [tribe, 'slots', tribe_target, 'committed'], 'leaf': [tribe, 'slots', tribe_target, 'occupied'], 'output': ''},
            {'receipt': [trade, 'slots', trade_target, 'committed'], 'leaf': [trade, 'leaf'], 'output': serum},
            {'receipt': [mix, 'slots', mix_target, 'committed'], 'leaf': [mix, 'leaf'], 'output': vapors}]}
    # Qualify every path against the real owners' literal initial shapes and
    # each source recipe's actual finite targets. Shared slot fields come from
    # Kit.slot(), not from a hand-written imitation of its schema.
    owner_shapes, schemas = {}, {}
    slot_shape = returned_dictionary(root/'scripts/lol2/mechanism_transaction.gd','slot')
    bindings = [
        ('l14_priest_ritual.gd','KEY','INGREDIENTS'),
        ('l14_niche.gd','KEY','TARGET'),
        ('l14_shard_bowls.gd','KEY','BOWLS'),
        ('l14_idol_pedestals.gd','KEY','CASES'),
        ('l14_hopper_platform.gd','KEY','IDS'),
        ('l14_flute_slot.gd','KEY','TARGET'),
        ('l13_altar_state.gd','KEY','TARGET'),
        ('l14_chamber_voices.gd','KEY',None),
        ('l10_ankh_state.gd','KEY',('TRADE','SLAB')),
        ('l10_emperor_state.gd','KEY',('INNER',)),
        ('l20_finale.gd','KEY',None),('l20_armory.gd','KEY',None),
        ('l13_exit_lock_state.gd','KEY','TARGET'),
        ('l14_spiral.gd','KEY','TARGET'),
        ('l8_temple_door_state.gd','KEY','TARGET'),
        ('l8_tree.gd','KEY',None),('hive_flute_floor.gd','KEY',None),
        ('l8_tribe_state.gd','KEY','TARGET'),
        ('l8_shaman_trade.gd','KEY','TARGET'),
        ('l8_larkhon_state.gd','KEY',('LEAF','SERUM','CHEST')),
        ('l10_silverleaf.gd','KEY',None),('l10_silverleaf_harvest.gd','KEY',None),
        ('l16_greenhouse.gd','KEY',None)]
    import copy
    for file,key_field,target_field in bindings:
        key=constant(file,key_field)
        shape=owner_initial(root/'scripts/lol2'/file)
        targets=[]
        if isinstance(target_field,tuple):
            targets=[constant(file,field) for field in target_field]
        elif target_field:
            targets=constant(file,target_field)
            if isinstance(targets,dict):targets=list(targets)
            elif isinstance(targets,str):targets=[targets]
        if not isinstance(targets,list) or any(not isinstance(t,str) for t in targets):raise ValueError('Invalid recipe targets: '+file)
        owner_shapes[key]={'file':file,'initial':shape,'targets':targets}
        schemas[key]=copy.deepcopy(shape)
        if targets:
            if 'slots' not in shape:raise ValueError('Recipe owner lacks slots: '+file)
            schemas[key]['slots']={target:copy.deepcopy(slot_shape) for target in targets}
    tree_target=constant('l8_tree_slot_state.gd','TARGET')
    schemas[constant('l8_tree.gd','KEY')]['lock']['slots']={tree_target:copy.deepcopy(slot_shape)}
    # Completed conjunctions have zero outstanding demand, even after the
    # consumed items are no longer in the live pack.
    for row in obligations:
        if row['name'] in ['Temple shards','Temple idols','Temple platform']:
            key=row['slots'][0]
            row['done']=[{'path':[key,'slots'],'all_committed':True,'targets':owner_shapes[key]['targets']}]
        for item in row['items']:
            if not isinstance(item,(str,int)):raise ValueError('Unqualified obligation item type')
            if not row['definitions'] and not isinstance(item,str):raise ValueError('Exact identity obligation contains a definition')
        for condition in row['done']:
            resolve(schemas,condition['path'])
        for place in row['slots']+row['recoverable']:
            path=place.get('path') if isinstance(place,dict) else ([place] if isinstance(place,str) else place)
            shape=resolve(schemas,path)
            if not isinstance(shape,dict) or not ('slots' in shape or 'slot' in shape):raise ValueError('Not a recoverable slot container: '+str(path))
    for path in [leaf_chain['mix_path'],leaf_chain['tribe_path'],leaf_chain['trade_path']]:resolve(schemas,path)
    for step in leaf_chain['steps']:
        resolve(schemas,step['receipt']);resolve(schemas,step['leaf'])
    for file in ['act2_items_catalog.gd', 'item_catalog.gd', 'mechanism_transaction.gd']:
        path = root / 'scripts/lol2' / file
        pins[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return {'version': 1, 'scope': 'Hosted main-road protection; counts from audited finite reserve_frontier; no whole-game softlock certificate.',
            'solver_sha256': hashlib.sha256(Path(__file__).with_name('quest_resource_model.py').read_bytes()).hexdigest(),
            'source_pins': pins, 'obligations': obligations, 'leaf_chain': leaf_chain, 'owner_shapes':owner_shapes}


def main():
    p = argparse.ArgumentParser(); p.add_argument('--check', action='store_true'); a = p.parse_args()
    text = json.dumps(build(), indent=2) + '\n'
    code = 'extends RefCounted\n## Generated by tools/build_quest_resource_policy.py; do not hand edit.\n## Direct preload keeps the runtime policy in resource exports without a JSON include filter.\nconst DATA := ' + text.strip() + '\n'
    if a.check:
        if not OUTPUT.is_file() or OUTPUT.read_text() != text or not PROVIDER.is_file() or PROVIDER.read_text() != code:
            raise SystemExit('FAIL quest policy/recipe/model changed; review then regenerate')
        print('PASS source-derived quest policy and model frontiers')
    else:
        OUTPUT.write_text(text)
        PROVIDER.write_text(code)


if __name__ == '__main__': main()
