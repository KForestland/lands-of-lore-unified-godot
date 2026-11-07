#!/usr/bin/env python3
"""Stage the Dark Halls (L7_DH) Rat and SHADE population in the scripted-creature schema (cf. prepare_cave_guard_population.py).

Actors: every present (placement flag0x1000 clear) Rat (definition1) and SHADE (definition0) placement, with source
position, heading, health and loot, and RIX (actor57, definition2: hostile melee; his talk and give-item branches are
not hosted, dark_halls.gd applies his death group 14414). The invisible B_HUMAN emitters are not hosted. No region wake
groups are staged, so every present creature is awake (scripted_creature_state: hunt within the alert range on sight).
Clips: idle/walk/rise/death/corpse from action rows 0/1/9/14/15. Rat attacks = its action5 rows (frame-event kind1 hits).
SHADE has no action5 row; its action7/8 states (11/12) cast at frame 11 (event kind5): staged as a 100% hit at that
frame (modern adapter; the native spell is not reproduced). Damage base: native_bases('Rat') = 15; SHADE's
constructor is not traced (native_bases raises on its code path) and takes the same 15 (adapter).
Writes PROJECT/scripts/lol2/dark_halls_population_source.json; sprites come from prepare_dark_halls_creature_sprites.py.
Usage: prepare_dark_halls_population.py --game GAME --sprites SPRITES_DIR [--project PROJECT]
"""
import argparse, hashlib, json, struct
from pathlib import Path
from build_game_atlas import parse_mix, section

ROOT = Path(__file__).resolve().parents[1]
DEFINITIONS = {'SHADE': 0, 'Rat': 1, 'RIX': 2}
SHADE_BASE = 15  # adapter, see docstring


def clips(d, base, name):
    sel = {}
    for i, row in enumerate(d['action_rows']): sel.setdefault(row[0], []).append(i)
    st = d['states']; n = lambda s: len(st[s]['views'][0]['frames'])
    attacks = []
    if 5 in sel:
        for s in sel[5]:
            hits = [(e['frame'], e['value_word'] & 255) for e in st[s]['frame_events'] if e['kind'] == 1]
            attacks.append(dict(selector=s, frames=n(s), hits=hits, damage=[base * p // 100 for _, p in hits]))
    else:
        for s in sel.get(7, []) + sel.get(8, []):
            casts = [e['frame'] for e in st[s]['frame_events'] if e['kind'] == 5]
            if casts: attacks.append(dict(selector=s, frames=n(s), hits=[(casts[0], 100)], damage=[base]))
    assert attacks, name
    return dict(idle=dict(selector=sel[0][0], frames=n(sel[0][0])), walk=dict(selector=sel[1][0], frames=n(sel[1][0])),
                rise=dict(selector=sel[9][0], frames=n(sel[9][0])), death=dict(selector=sel[14][0], frames=n(sel[14][0])),
                corpse=dict(selector=sel[15][0], frames=n(sel[15][0])), attacks=attacks)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--sprites', type=Path, required=True)
    p.add_argument('--actors', type=Path, default=Path('~/lol2_github_source_20260911/docs/game-actors.json'))
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    area = next(x for x in json.loads(a.actors.read_text())['areas'] if x['id'] == 'L7_DH')
    archive = (a.game / area['source']['file']).read_bytes()
    assert hashlib.sha256(archive).hexdigest() == area['source']['sha256'], 'Unsupported L7_DH archive'
    ge = next(e for e in parse_mix(archive) if e['key'] == area['source']['geometry_key'])
    geo = archive[ge['offset']:ge['offset'] + ge['size']]
    _, count, pl = section(geo, 0x1c, 0x68, 56)
    definitions = {d['definition']: d for d in area['definitions']}
    sprites = json.loads((a.sprites / 'sprites.json').read_text())
    actors = []
    for row in area['actors']:
        if row['name'] not in DEFINITIONS: continue
        i = row['actor']; r = pl[i * 56:(i + 1) * 56]
        x, z, h, y = struct.unpack_from('<hhHh', r, 0)
        flags = struct.unpack_from('<H', r, 8)[0]
        if flags & 0x1000: continue
        loot = struct.unpack_from('<I', r, 52)[0]
        d = row['definition']
        actors.append(dict(actor=i, definition=d, position=[x, y, -z], heading=h, health=struct.unpack_from('<H', r, 30)[0],
                           behavior=r[37], flags=flags, present=True, loot=loot or None,
                           reward_scale=archive[definitions[d]['archive_offset'] + 0x83]))
    from verify_cave_roach_attack import native_bases
    b = native_bases('Rat'); fresh = [k for k, v in b['constructors'].items() if 0 in v]; assert len(fresh) == 1
    rat_base = fresh[0][0]
    r = native_bases('RIX'); rix_fresh = [k for k, v in r['constructors'].items() if 0 in v]; assert len(rix_fresh) == 1
    defs, bases = {}, {'Rat': dict(base=rat_base, total81=b['total'], minimum82=b['minimum'], stat_sha256=b['raw_sha256']),
                       'RIX': dict(base=rix_fresh[0][0], total81=r['total'], minimum82=r['minimum'], stat_sha256=r['raw_sha256']),
                       'SHADE': dict(base=SHADE_BASE, total81=b['total'], minimum82=b['minimum'], stat_sha256=b['raw_sha256'], adapter='Rat stats')}
    for key, d in sprites['definitions'].items():
        if d['name'] not in DEFINITIONS: continue
        defs[key] = dict(name=d['name'], clips=clips(d, bases[d['name']]['base'], d['name']))
    result = dict(version=1, source=area['source'], actors=actors, definitions=defs, native_bases=bases, regions=[], neighbour_wake={},
                  counted=[], counter_target=0, scripted_dormant=[], controls=[])
    out = a.project / 'scripts/lol2/dark_halls_population_source.json'
    out.write_text(json.dumps(result, indent=1) + '\n')
    print(f"PASS Dark Halls population: {sum(x['definition'] == 1 for x in actors)} rats, {sum(x['definition'] == 0 for x in actors)} shades, {sum(x['definition'] == 2 for x in actors)} Rix; "
          f"attacks { {k: [(t['selector'], t['hits'], t['damage']) for t in v['clips']['attacks']] for k, v in defs.items()} }")


if __name__ == '__main__':
    main()
