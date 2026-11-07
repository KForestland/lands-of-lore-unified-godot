#!/usr/bin/env python3
"""Pin the Huline Jungle alert-before-first-meeting Bacatta encounter (prop553 template84, actor65) as a source contract.

Every record, command group and predicate is read from the hash-checked L4_HJ archive and asserted byte for byte.
Scope: prop553 (all 70 records), actor65 (2 records), the prop3235 kind5 starter and regions 576/577/582/601/
3890-3892/3895-3897 (first entry / walk-away) and 3157 (removal once GV_MET_BACATTA==1).
Native facts used by the state component (LOLG.DAT, static):
- ADDE0(list, value) raises kind6 records whose value byte matches; predicates are tested when queued.
- Movie owner 9EBFC asks the VQA player 113BF0 for its status: 4 (a pass ended while the repeat counter +0x30 is
  nonzero; the counter is decremented, -1 never) raises kind6 value1; 5 (final end) raises kind6 value0. So a
  repeating clip reports value1 at every wrap and value0 only when its repeat count is spent.
- Creature opcode13 (table 0x4D2A4 slot10 -> A677A, sub table 0x4D248): sub13 sets B5 bits 0x0C, sub7 clears bit 1
  (hostile, as hive_dawn20_state.gd), sub17 (0x11) at A660D calls A7544(actor, 0) and clears +0x7C: the actor's own
  behaviour decision is re-run; the parameter byte is not read.
- kind9 records are AE2C8 mode1 (byte9 & 7 == 1), threshold byte8, wildcard masks, not one-shot.
- kind4 records are mode1 (any held item), first eligible record wins (hive_dawn20_state.gd offer()).
- The prop553 kind2 timer row: flags1 (stopped), countdown 180 ticks, range [0,3] (60 ticks/s, Dawn20 timer owner).
"""
import hashlib, json, struct, sys
from pathlib import Path
from build_game_atlas import parse_mix, section
from audit_game_actor_scripts import groups
from audit_game_transition_owners import GAME, collect_owners
from prepare_jungle_exit_encounter import predicate
import prepare_jungle_bacatta as B
ROOT = Path(__file__).resolve().parents[1]
PROP, ACTOR, STARTER = 553, 65, 3235
FIRST, AWAY, REMOVAL = (577, 582, 3895, 3896, 3897), (576, 601, 3890, 3891, 3892), 3157
EXPECTED_GROUPS = {
    (1, 16958): ['090329020300', '090329021500'],
    (1, 11826): ['020329020500', '0803290202000000', '080329020700ff00', '080329020a000100'],
    (1, 12514): ['020329020600', 'c60000000205', '020100002700', '0803290201000000', '090329020200', '090241000300', '0d0241000d000000', '0d02410007000000'],
    (1, 12888): ['020329020600', 'c60000000205', '020100002700', '0803290201000000', '090241000300', '0d02410011030000', '090329020200'],
    (1, 12438): ['0e03290204000000', '0803290201000000', '100329021400', '050329021300'],
    (0, 5570): ['090241000200', '090239000200'],
}

def main():
    inventory = json.loads((ROOT / 'docs/game-source-inventory.json').read_text())
    area = next(a for a in inventory['areas'] if a['id'] == 'L4_HJ')
    archive = (GAME / area['source']['file']).read_bytes(); assert hashlib.sha256(archive).hexdigest() == area['source']['sha256']
    entry = next(e for e in parse_mix(archive) if e['key'] == area['source']['geometry_key'])
    raw = archive[entry['offset']:entry['offset'] + entry['size']]; assert hashlib.sha256(raw).hexdigest() == area['source']['geometry_sha256']
    owners, _ = collect_owners(raw, entry['offset'], area['counts']['regions'])
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    parsed = {}
    for stream, (of, sf) in enumerate([(0x3c, 0x84), (0x44, 0x8c)]):
        _, _, blob = section(raw, of, sf, 1)
        for group, commands in groups(blob): parsed[(stream, group)] = [body.hex() for _, body in commands]
    for key, expected in EXPECTED_GROUPS.items(): assert parsed[key] == expected, (key, parsed[key])
    records = []
    for o in owners:
        k, n_ = o['owner_kind'], o['owner']
        mine = (k == 'prop' and n_ == PROP) or (k == 'actor' and n_ == ACTOR) or (k == 'region' and n_ in FIRST + AWAY + (REMOVAL,)) or (k == 'prop' and n_ == STARTER and o['event'] == 5)
        # Regions 3895-3897 also run an unrelated object-link group (objects 78-81); only the encounter's own groups are pinned.
        if mine and k == 'region' and not any(c[2:8] in ('032902', '024100') for c in parsed[(o['stream'], o['group'])]): continue
        if not mine: continue
        n = archive[o['archive_offset']]
        records.append(dict(owner_kind=k, owner=n_, kind=o['event'], value=o['value'], stream=o['stream'], group=o['group'],
                            predicate=o['predicate'], raw=archive[o['archive_offset']:o['archive_offset'] + n].hex(), commands=parsed[(o['stream'], o['group'])]))
    count = lambda k, owner=None: sum(r['owner_kind'] == k and (owner is None or r['owner'] == owner) for r in records)
    assert (count('prop', PROP), count('actor', ACTOR), count('prop', STARTER), count('region')) == (69, 2, 1, 11), (count('prop', PROP), count('actor'), count('region'))
    # Every other owner that names prop553 or actor65 in a command is in scope (completeness).
    targets = {'prop': PROP, 'actor': ACTOR}
    for o in owners:
        cmds = parsed[(o['stream'], o['group'])]
        names = any(c[2:8] in ('032902', '024100') for c in cmds)
        if names: assert any(r['group'] == o['group'] and r['stream'] == o['stream'] for r in records), (o['owner_kind'], o['owner'], o['group'])
    # Native record shapes.
    hits = [r for r in records if r['kind'] == 9]
    assert len(hits) == 3 and all(bytes.fromhex(r['raw'])[9] == 1 and bytes.fromhex(r['raw'])[8] == 1 and bytes.fromhex(r['raw'])[4:8] == bytes(4) for r in hits)
    offers = [r for r in records if r['kind'] == 4]
    assert len(offers) == 3 and all(bytes.fromhex(r['raw'])[4] == 1 for r in offers)
    timer = [r for r in records if r['owner_kind'] == 'prop' and r['kind'] == 2]
    assert len(timer) == 1; tb = bytes.fromhex(timer[0]['raw'])
    timers = [dict(ordinal=0, group=struct.unpack_from('<H', tb, 2)[0], flags=tb[5], range=[tb[7], tb[6]], remaining=struct.unpack_from('<H', tb, 8)[0], predicate=timer[0]['predicate'])]
    assert timers[0]['flags'] == 1 and timers[0]['remaining'] == 180 and timers[0]['group'] == 12438
    predicates = {}
    def add(p):
        if p is None or str(p) in predicates: return
        predicates[str(p)] = predicate(table, p)
    for r in records: add(r['predicate'])
    for row in timers: add(row['predicate'])
    for p in predicates.values():
        for side in (p['left'], p['right']):
            assert set(side) <= {'immediate', 'local', 'owner_state', 'shared', 'predicate', 'expression'}, p
    _, _, props = section(raw, 0x14, 0x60, 37); _, _, actors = section(raw, 0x1c, 0x68, 56)
    def prop_row(pid):
        p = props[pid * 37:(pid + 1) * 37]; px, pz, h, py = struct.unpack_from('<hhHh', p, 0)
        return dict(id=pid, position=[px, py, -pz], heading=h, flags=struct.unpack_from('<H', p, 8)[0], template=struct.unpack_from('<H', p, 32)[0])
    prop, starter = prop_row(PROP), prop_row(STARTER)
    assert prop['template'] == 84 and prop['flags'] & 0x1000 == 0x1000 and starter['template'] == 30 and not starter['flags'] & 0x1000
    r = actors[ACTOR * 56:(ACTOR + 1) * 56]; x, z, h, y = struct.unpack_from('<hhHh', r, 0); flags = struct.unpack_from('<H', r, 8)[0]
    actor = dict(id=ACTOR, position=[x, y, -z], heading=h, flags=flags, definition=r[32], health=struct.unpack_from('<H', r, 30)[0], behavior=r[37])
    assert flags & 0x1000 and actor['definition'] == 5 and actor['health'] == 200 and actor['behavior'] == 4
    tex = B.TEXTURE.read_bytes(); sec = B.sections(tex)
    metas = [e for e in parse_mix(archive) if archive[e['offset']:e['offset'] + 8] == struct.pack('<II', 18, 516)]; assert len(metas) == 1
    meta = archive[metas[0]['offset']:metas[0]['offset'] + metas[0]['size']]
    selectors = {str(i): dict(vqa=B.vqa_name(tex, sec, res[0]), resource=res[0]) for i, res in enumerate(B.template_selectors(meta, 84)) if i <= 29}
    assert len(selectors) == 30 and all(s['vqa'] for s in selectors.values())
    assert {selectors[k]['vqa'] for k in ('0', '5', '10', '15')} == {'BC08.VQA'} and selectors['1']['vqa'] == '1370004E.VQA' and selectors['29']['vqa'] == '1372704E.VQA'
    geometry = json.loads(B.GEOMETRY.read_text())
    def polygon(index):
        reg = geometry['regions'][index]; assert reg['id'] == index
        return dict(region=index, polygon=[[geometry['vertices_fixed'][v][0] / 65536, -geometry['vertices_fixed'][v][1] / 65536] for v in reg['vertex_indices']],
                    floor_min=min(reg['floor_corners']), floor_max=max(reg['floor_corners']))
    regions = [polygon(i) for i in FIRST + AWAY + (REMOVAL,)]
    result = dict(version=1, source=area['source'], prop=dict(prop, present=False, selectors=selectors), starter=starter, actor=actor,
                  regions=regions, first_regions=list(FIRST), away_regions=list(AWAY), removal_region=REMOVAL,
                  records=records, predicates=predicates, timers=timers, owned_locals=[2, 3],
                  shared_names={'0': 'GV_LUTHERS_SOUL', '13': 'GV_BACATTA_RELATIONSHIP', '18': 'GV_MET_BACATTA', '29': 'GV_HULINE_ALERT'},
                  shared_caps={'0': 10, '13': 2, '18': 255, '29': 255},
                  idle_selectors=[0, 5, 10, 15])
    # Body owner: the generic creature population with Bacatta61's BACL4 definition5 row, placed as actor65.
    template = json.loads((ROOT / 'scripts/lol2/jungle_bacatta_population_source.json').read_text())
    assert template['source'] == area['source'] and list(template['definitions']) == ['5']
    body = dict(template['actors'][0], actor=ACTOR, position=actor['position'], heading=actor['heading'], health=actor['health'],
                behavior=actor['behavior'], flags=actor['flags'], present=False)
    population = dict(template, actors=[body], scripted_dormant=[ACTOR],
                      note='actor65 body (BACL4 definition5, as Bacatta61): peaceful after outcome B, hostile after outcome A; death/corpse use the idle frame.')
    (ROOT / 'scripts/lol2/jungle_bacatta65_population_source.json').write_text(json.dumps(population, indent=1) + '\n')
    out = ROOT / 'scripts/lol2/jungle_bacatta65_source.json'
    out.write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS prop553/actor65 source: {len(records)} records, {len(predicates)} predicates, timer {timers[0]}, selectors 0-29, regions {[r["region"] for r in regions]}')

if __name__ == '__main__':
    main()
