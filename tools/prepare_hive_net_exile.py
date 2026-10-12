#!/usr/bin/env python3
"""Pin Hive prop214 (template42 selector2, a bone-and-branch pile) and its single grant "26-Net of Exile".

prop214 has one record: kind4 mode0 (empty hand) at owner state0, group1632: op3 player "26-Net of Exile"
(identity 0x1EDB305A, property4: one item) and op16 state1. The selector does not change, so the pile stays.
The item is GLOBAL definition25, handler104 (0x9B718): only event17 is handled; when the struck target's class is 2
it allocates pool object 0x7A and calls the family-4 effect constructor 10E2F8 (attacker, target). That on-hit
effect is not hosted; the port treats the Net as a weapon for the shared melee adapter.
The pile is not among the staged single-state Hive props, so its original sprite (props/sprites/prop_229.png of the
pinned all-maps export) is staged here.
Usage: prepare_hive_net_exile.py --output scripts/lol2/hive_net_exile_source.json --asset-dir assets/lol2/generated/hive_net_exile
"""
import argparse, hashlib, json, shutil, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ALLMAP = Path('/home/bob/lol2_out/all_maps_20260922/L5_HC')
NET = dict(identity=0x1EDB305A, name='26-Net of Exile', definition=25, handler=104)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True); p.add_argument('--asset-dir', type=Path, required=True)
    a = p.parse_args(); a.asset_dir.mkdir(parents=True, exist_ok=True)
    area, arc, entry, raw, owners, streams = source_area('L5_HC')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    rows = [r for r in owners if r['owner_kind'] == 'prop' and r['owner'] == 214]
    assert len(rows) == 1 and rows[0]['event'] == 4 and rows[0]['group'] == 1632
    assert predicate(table, rows[0]['predicate'])['raw'] == '0005000000'
    record = arc[rows[0]['archive_offset']:rows[0]['archive_offset'] + arc[rows[0]['archive_offset']]].hex()
    assert record == '0a046006000000000000', record  # kind4, mode0 (empty hand)
    commands = [c['raw_hex'] for c in streams[rows[0]['stream']][1632]]
    assert commands == ['03010000' + struct.pack('<I', NET['identity']).hex() + '04000000', '1003d6000100'], commands
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_museum_key_locks import definitions, icon
    from build_game_atlas import u32
    blob, base, n, names = definitions()
    d = blob[base + NET['definition'] * 91:base + (NET['definition'] + 1) * 91]
    assert names[NET['definition']] == NET['name'] and u32(d, 24) == NET['identity'] and d[0x42] == NET['handler']
    icon(NET['definition'], a.asset_dir / 'net.png')
    exported = {q['record']: q for q in json.loads((ALLMAP / 'props/props.json').read_text())['props']}
    q = exported[214]
    assert q['template'] == 42 and q['selector'] == 2 and q['material'] == 'prop_229' and q['region'] == 350 and not q['animated']
    shutil.copyfile(ALLMAP / 'props/sprites/prop_229.png', a.asset_dir / 'pile.png')
    result = dict(version=1, source=area['source'], prop=214, group=1632, record=record, commands=commands, item=NET,
                  position=q['position'], region=q['region'], sprite=dict(file='pile.png', left=q['left'], right=q['right'], bottom=q['bottom'], top=q['top'],
                                                                         sha256=hashlib.sha256((a.asset_dir / 'pile.png').read_bytes()).hexdigest()),
                  handler=dict(address='0x9B718', event=17, effect='target class2 -> pool object 0x7A, family-4 constructor 10E2F8 (not hosted)'),
                  adapters=['E with an empty hand at the aimed pile in reach is the kind4 mode0 producer; the Net goes straight to the Hive inventory',
                            'the Net is a catalog weapon using the shared melee adapter; its handler104 on-hit effect is not hosted'],
                  scope='Direct source record and grant; prop selector unchanged (the pile stays).')
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS hive net of exile: prop214 g1632, definition25 handler104, pile sprite staged')


if __name__ == '__main__':
    main()
