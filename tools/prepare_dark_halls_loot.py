#!/usr/bin/env python3
"""Stage the Dark Halls (L7_DH) item givers: static-assembly controls whose use event (event4) runs an op3 item grant.

Source (verify_actor_item_grants.source_area): control58 g7044 "47-Stone bracrs", control59 g7084 "45-Fire shield",
control71 g7608 "85-Colims amult" (predicate206 = first use), controls 968/971/974/975/976 first use (206) and second
use (207): healing / prism / spark / summon scrolls and an Ancients stone. Not staged: prop212 event5 g328 (six mixed
items, owner semantics unknown) and actor57 RIX g14496 "14-Plasma staff" (Rix is not hosted).
Positions come from the L7 static-assembly placements; item names from GLOBAL definitions by identity; icons are the
definition's first-selector inventory image (the jungle world-item recipe). Item use semantics are not replayed: the
grant only adds the item to the carried inventory.
Usage: prepare_dark_halls_loot.py --game GAME --placements STATIC_ASSEMBLIES_MOVABLES_JSON [--project PROJECT]
"""
import argparse, hashlib, json, struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix, u32
from lol2_material_format import sections, rgb_palette
from lol2_creature_sprite_format import decode_rows
from verify_actor_item_grants import source_area

ROOT = Path(__file__).resolve().parents[1]
CONTROLS = [58, 59, 71, 968, 971, 974, 975, 976]
USES = {206: 1, 207: 2}  # predicate206/207 = owner state 0/1 -> first/second use


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--placements', type=Path, required=True)
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    game = a.game.resolve()
    def entry(filename, key):
        raw = (game / filename).read_bytes()
        m = [e for e in parse_mix(raw) if e['key'] == key]; assert len(m) == 1
        return raw[m[0]['offset']:m[0]['offset'] + m[0]['size']]
    definitions = entry('GLOBAL.MIX', 3984507021)
    base, count = u32(definitions, 4), u32(definitions, 0x34)
    state = base + count * 91 + 4; view = state + u32(definitions, state - 4) * 16 + 4; names = view + u32(definitions, view - 4) * 12
    first = {}; state_index = view_index = 0
    for index in range(count):
        record = definitions[base + index * 91:][:91]
        for sel in range(record[46] + record[47]):
            views = max(1, struct.unpack_from('<b', definitions, state + state_index * 16 + 13)[0])
            if sel == 0: first[index] = struct.unpack_from('<h', definitions, view + view_index * 12)[0]
            state_index += 1; view_index += views
    by_identity = {u32(definitions[base + i * 91:][:91], 24): i for i in range(count)}
    graphics = entry('LOCAL.MIX', 4018716831)
    sec = sections(graphics); palette = rgb_palette(graphics[u32(graphics, 4):][:768], 6)
    _, _, _, _, owners, streams = source_area('L7_DH', game)
    groups = {}
    for stream in streams:
        for gid, cmds in stream.items(): groups.setdefault(int(gid), []).extend(cmds)
    placements = {p['source_index']: p for p in json.loads(a.placements.read_text())['placements']}
    out = a.project / 'assets/lol2/generated/dark_halls_loot'; out.mkdir(parents=True, exist_ok=True)
    controls = []
    for control in CONTROLS:
        grants = []
        for o in owners:
            if o['owner_kind'] != 'control' or o['owner'] != control or o['event'] != 4 or o['predicate'] not in USES: continue
            for c in groups[o['group']]:
                raw = bytes.fromhex(c['raw_hex'])
                if raw[0] != 3: continue
                identity = u32(raw, 4); d = by_identity[identity]
                name = definitions[names + d * 30:names + d * 30 + 24].split(b'\0')[0].decode()
                resource = first[d]; desc = struct.unpack_from('<6H11I', graphics, sec[2] + resource * 56)
                width, height, pixels, _ = decode_rows(graphics[sec[3] + desc[7]:][:desc[12]], allow_special=True)
                stem = name.split('-', 1)[1].replace(' ', '_')
                icon = f'{stem.lower()}.png'
                Image.frombytes('RGBA', (width, height), bytes(ch for px in pixels for ch in (*palette[px * 3:px * 3 + 3], 0 if px in (0, 1) else 255))).save(out / icon)
                grants.append(dict(use=USES[o['predicate']], group=o['group'], predicate=o['predicate'], name=name, label=name.split('-', 1)[1],
                                   id=f'darkhalls:control{control}u{USES[o["predicate"]]}:{stem}', identity=identity, definition=d,
                                   icon='res://assets/lol2/generated/dark_halls_loot/' + icon, command_hex=c['raw_hex']))
        assert grants, control
        pl = placements[control]
        controls.append(dict(control=control, template=pl['template'], native=[pl['x'], pl['y'], pl['height']], heading=pl['heading'],
                             position=[pl['x'], pl['height'], -pl['y']], grants=sorted(grants, key=lambda g: g['use'])))
    # RIX (actor57): death group 14414 and the event4/predicate216 corpse grant 14496 (dark_halls_rix.gd).
    def grant_of(group):
        for c in groups[group]:
            raw = bytes.fromhex(c['raw_hex'])
            if raw[0] == 3:
                identity = u32(raw, 4); d = by_identity[identity]
                name = definitions[names + d * 30:names + d * 30 + 24].split(b'\0')[0].decode()
                resource = first[d]; desc = struct.unpack_from('<6H11I', graphics, sec[2] + resource * 56)
                width, height, pixels, _ = decode_rows(graphics[sec[3] + desc[7]:][:desc[12]], allow_special=True)
                stem = name.split('-', 1)[1].replace(' ', '_'); icon = f'{stem.lower()}.png'
                Image.frombytes('RGBA', (width, height), bytes(ch for px in pixels for ch in (*palette[px * 3:px * 3 + 3], 0 if px in (0, 1) else 255))).save(out / icon)
                return dict(group=group, name=name, label=name.split('-', 1)[1], id=f'darkhalls:actor57:{stem}', identity=identity, definition=d,
                            icon='res://assets/lol2/generated/dark_halls_loot/' + icon, command_hex=c['raw_hex'])
    death = [o for o in owners if o['owner_kind'] == 'actor' and o['owner'] == 57 and o['event'] == 9 and o['predicate'] is None]
    corpse = [o for o in owners if o['owner_kind'] == 'actor' and o['owner'] == 57 and o['event'] == 4 and o['predicate'] == 216]
    assert len(death) == 1 and len(corpse) == 1
    rix = dict(actor=57, death_group=death[0]['group'], death_commands=[c['raw_hex'] for c in groups[death[0]['group']]],
               corpse=grant_of(corpse[0]['group']))
    assert 'ce00000000ff' in rix['death_commands'], 'Rix death no longer lowers the soul by 1'
    result = dict(version=1, archive='DAT/L7_DH.MIX', definitions_sha256=hashlib.sha256(definitions).hexdigest(), controls=controls, rix=rix,
                  not_hosted=['prop212 event5 g328 (six items)', 'actor57 talk/give branches (g14102/g14186/g14234/g14330 soul +2)'],
                  scope='Original L7 item-giving controls (event4 use, predicate206 first / 207 second). Use semantics of the items are not replayed.')
    (a.project / 'scripts/lol2/dark_halls_loot_source.json').write_text(json.dumps(result, indent=1) + '\n')
    print('PASS Dark Halls loot:', [(c['control'], [g['label'] for g in c['grants']]) for c in controls])


if __name__ == '__main__':
    main()
