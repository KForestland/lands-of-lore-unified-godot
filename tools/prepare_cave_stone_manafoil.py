#!/usr/bin/env python3
"""Pin the Cave Ancient Stone (prop1050) and Mana foil (control75) producers and stage their art and item icons.

prop1050 (template53, sprite prop_477, region751): kind4 mode0 at owner state0 (predicate4), group8846: op9 property16
  on itself (B5401 -> E416C(23C68, prop, 1): the object goes to the hand presentation), op3 "66-Ancients stn"
  (identity 0xE0649CBA, property1), op16 state1. kind6 event9 (startup scanner) group8876: op20 sound only.
control75 (static assembly template46 at (209,-1000,-10691); child85 always, child86 only at selector0):
  kind4 mode0 while local16 == 0 (predicate41), group9750: op2 player sub 0x29 (D86B6: first-time help, player
  +0x20C bit0 and 73FF0(1)), op198 local16 = 1. kind3 value1 (selector1 reached), group9768: op3 "131-Mana foil"
  (identity 0xC221EB6B, property4). No selector1 producer was found in the audited scope (every command of both
  L1_DC streams; the only direct caller of setter F2944 is the op5 class virtual A7DC4). Computed/indirect virtual
  calls were not enumerated. The port's selector1 producer is therefore a modern adapter.
Usage: prepare_cave_stone_manafoil.py --output scripts/lol2/cave_stone_manafoil_source.json --asset-dir assets/lol2/generated/cave_stone_manafoil
"""
import argparse, hashlib, json, shutil, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ALLMAP = Path('/home/bob/lol2_out/all_maps_20260922/L1_DC')
STONE = dict(identity=0xE0649CBA, name='66-Ancients stn', definition=68, handler=6)
FOIL = dict(identity=0xC221EB6B, name='131-Mana foil', definition=133, handler=43)


def grant(item, prop):
    return '03010000' + struct.pack('<I', item['identity']).hex() + '%02x000000' % prop


def rows(owners, streams, arc, table, kind, n):
    out = []
    for r in [r for r in owners if r['owner_kind'] == kind and r['owner'] == n]:
        out.append(dict(kind=r['event'], value=r['value'], group=r['group'], predicate=predicate(table, r['predicate'])['raw'] if r['predicate'] is not None else None,
                        commands=[c['raw_hex'] for c in streams[r['stream']][r['group']]], raw=arc[r['archive_offset']:r['archive_offset'] + arc[r['archive_offset']]].hex()))
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True); p.add_argument('--asset-dir', type=Path, required=True)
    a = p.parse_args(); a.asset_dir.mkdir(parents=True, exist_ok=True)
    area, arc, entry, raw, owners, streams = source_area('L1_DC')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    stone = rows(owners, streams, arc, table, 'prop', 1050)
    use = next(r for r in stone if r['kind'] == 4); arrival = next(r for r in stone if r['kind'] == 6)
    assert len(stone) == 2 and use['group'] == 8846 and use['predicate'] == '0005000000' and use['raw'] == '0a048e22000000000000'
    assert use['commands'] == ['09031a041000', grant(STONE, 1), '10031a040100'], use
    assert arrival['group'] == 8876 and arrival['raw'] == '0606ac220900' and arrival['commands'] == ['14031a04470280020b14'], arrival
    foil = rows(owners, streams, arc, table, 'control', 75)
    use75 = next(r for r in foil if r['kind'] == 4); sel75 = next(r for r in foil if r['kind'] == 3)
    assert len(foil) == 2 and use75['group'] == 9750 and use75['predicate'] == '0003100000' and use75['raw'] == '0a041626000000000000'
    assert use75['commands'] == ['020100002900', 'c60000001001'], use75
    assert sel75['group'] == 9768 and sel75['value'] == 1 and sel75['predicate'] is None and sel75['commands'] == [grant(FOIL, 4)], sel75
    # No selector writer for control75 in either stream.
    assert not any(c['raw_hex'][2:8] == '104b00' for st in streams for cmds in st.values() for c in cmds)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_museum_key_locks import definitions, icon
    from build_game_atlas import u32
    blob, base, n, names = definitions()
    for item in (STONE, FOIL):
        d = blob[base + item['definition'] * 91:base + (item['definition'] + 1) * 91]
        assert names[item['definition']] == item['name'] and u32(d, 24) == item['identity'] and d[0x42] == item['handler'], item
    icon(STONE['definition'], a.asset_dir / 'stone_icon.png'); icon(FOIL['definition'], a.asset_dir / 'foil_icon.png')
    props = {q['record']: q for q in json.loads((ALLMAP / 'props/props.json').read_text())['props']}
    q = props[1050]; assert q['template'] == 53 and q['selector'] == 0 and q['material'] == 'prop_477' and q['region'] == 751
    shutil.copyfile(ALLMAP / 'props/sprites/prop_477.png', a.asset_dir / 'stone.png')
    assemblies = json.loads((ALLMAP / 'static_assemblies/movables.json').read_text())
    assert assemblies['source']['sha256'] == area['source']['sha256']
    place = next(x for x in assemblies['placements'] if x['source_index'] == 75); assert place['template'] == 46
    faces = []
    for f in assemblies['faces'] + assemblies['state_faces']:
        if f['source_index'] != 75: continue
        if f['resource_id'] != 86: continue  # resource93 (child86 top) is an encoding the exporter rejects (0x2C6)
        faces.append(dict(points=f['points'], uv=f['uv'], child=f['child'], child_mask=f['child_mask']))
    assert faces and {f['child'] for f in faces} == {85}, {f['child'] for f in faces}
    shutil.copyfile(ALLMAP / 'material_0086/mip_0_palette.png', a.asset_dir / 'm0086.png')
    result = dict(version=1, source=area['source'],
                  stone=dict(prop=1050, item=STONE, use_group=8846, arrival_group=8876, position=q['position'], region=q['region'],
                             sprite=dict(file='stone.png', left=q['left'], right=q['right'], bottom=q['bottom'], top=q['top'])),
                  foil=dict(control=75, item=FOIL, use_group=9750, selector_group=9768, help_local=16, position=[place['x'], place['height'], -place['y']],
                            template=46, faces=faces, box_material='m0086.png'),
                  adapters=['E at the aimed pickup in reach is the kind4 mode0 producer',
                            'prop1050 is hidden after the take (op9 property16 hands the object to the native hand presentation)',
                            'control75: E runs group9750 when local16 is 0 (the help screen of op2 sub 0x29 is not hosted), then advances the selector to 1, which runs the source kind3 group9768 grant once; no selector writer was found in the audited scope (direct dispatch and both streams)',
                            'the displayed child86 (resource93, rejected encoding) is shown by the Mana foil item icon above the box until the take'],
                  scope='Direct source records and grants; the control75 selector producer is a documented modern adapter.')
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS cave stone/manafoil: prop1050 g8846/g8876, control75 g9750/g9768, %d box faces' % len(faces))


if __name__ == '__main__':
    main()
