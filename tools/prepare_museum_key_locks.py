#!/usr/bin/env python3
"""Pin the 17 Museum skull-key locks (L3_DH controls 78/87/88/113/114/140-151) and their key-bearing targets.

Every lock has exactly one kind4 mode3 record that requires the held identity 394988083 ("92-Sk key", GLOBAL
definition94) and one kind4 mode0 (empty hand) record. Mode3 consumes the held key (op2) and writes the lock's
storage (op16 owner state, or op198 local for controls 78/114/141/142/144); mode0 grants exactly one key (op3; 95B68
allocates one item and stores the last byte as an item property, not a count). Placed objects start at owner
state 0 (constructors AE9EE/AEA66/AEB21 zero object+0x25) and these locals are written only by their own lock, so
the lock is loaded iff its storage equals the mode0 predicate value: only control87 (inverted) starts loaded.
Targets: control140 drives movables53/51 (the gallery lever/grate), control113 selector1 lights sconce controls
117-139, control114 lowers movable55 whose own mode0/mode3 records give/take "68-SS1".
Usage: prepare_museum_key_locks.py --output scripts/lol2/museum_key_locks_source.json [--icon-dir DIR]
"""
import argparse, hashlib, json, struct
from pathlib import Path
from build_game_atlas import parse_mix, section, u32
from audit_game_transition_owners import GAME, collect_owners
from audit_game_actor_scripts import groups
from prepare_jungle_exit_encounter import predicate

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('/home/bob/lol2_out/all_maps_20260922/L3_DH')
LOCKS = [78, 87, 88, 113, 114] + list(range(140, 152))
SCONCES = list(range(117, 140))
KEY = dict(identity=394988083, definition=94, name='92-Sk key', catalog_id='museum:control87:Sk_key', icon='sk_key.png')
SS1 = dict(identity=0xa65aa1bf, name='68-SS1', catalog_id='museum:movable55:SS1', icon='ss1.png')
DEFINITIONS_SHA = 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'


def definitions():
    ga = (GAME / 'GLOBAL.MIX').read_bytes(); ge = next(e for e in parse_mix(ga) if e['key'] == 3984507021)
    blob = ga[ge['offset']:ge['offset'] + ge['size']]; assert hashlib.sha256(blob).hexdigest() == DEFINITIONS_SHA
    base, count = u32(blob, 4), u32(blob, 0x34); names = base + count * 91 + 4
    names += u32(blob, names - 4) * 16 + 4; names += u32(blob, names - 4) * 12
    return blob, base, count, {i: blob[names + i * 30:names + i * 30 + 24].split(b'\0')[0].decode() for i in range(count)}


def storage(pred):
    left = pred['left']; value = pred['right']['immediate']; assert pred['op'] == '==' and value in (0, 1)
    if left.get('owner_state'): return dict(kind='owner_state'), value
    return dict(kind='local', index=left['local']), value


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True); p.add_argument('--icon-dir', type=Path)
    p.add_argument('--passage-output', type=Path, help='lock78 passage faces (closed-only/open-only museum_review faces)')
    a = p.parse_args()
    inv = json.loads((ROOT / 'docs/game-source-inventory.json').read_text()); area = next(x for x in inv['areas'] if x['id'] == 'L3_DH')
    arc = (GAME / area['source']['file']).read_bytes(); assert hashlib.sha256(arc).hexdigest() == area['source']['sha256']
    entry = next(e for e in parse_mix(arc) if e['key'] == area['source']['geometry_key'])
    raw = arc[entry['offset']:entry['offset'] + entry['size']]; assert hashlib.sha256(raw).hexdigest() == area['source']['geometry_sha256']
    owners, _ = collect_owners(raw, entry['offset'], area['counts']['regions']); _, _, table = section(raw, 0xbc, 0xb8, 5)
    streams = []
    for of, sf in [(0x3c, 0x84), (0x44, 0x8c)]:
        _, _, blob = section(raw, of, sf, 1); streams.append({g: [b.hex() for _, b in c] for g, c in groups(blob)})

    def records(kind, owner):
        out = []
        for o in owners:
            if o['owner_kind'] != kind or o['owner'] != owner: continue
            n = arc[o['archive_offset']]; r = arc[o['archive_offset']:o['archive_offset'] + n]
            rec = dict(kind=o['event'], value=o['value'], group=o['group'], predicate=o['predicate'], raw=r.hex(),
                       predicate_expression=predicate(table, o['predicate']) if o['predicate'] is not None else None,
                       commands=streams[o['stream']][o['group']])
            if o['event'] == 4: rec.update(mode=r[4], held_identity=struct.unpack_from('<I', r, 6)[0])
            out.append(rec)
        return out

    statics = {q['source_index']: q for q in json.loads((MAP / 'static_assemblies/movables.json').read_text())['placements']}
    movables = {q['source_index']: q for q in json.loads((MAP / 'movables/movables.json').read_text())['placements']}
    for d in (statics, movables):
        for q in d.values(): assert arc[q['placement_offset']:q['placement_offset'] + len(q['placement_hex']) // 2].hex() == q['placement_hex']
    place = lambda q: dict(position=[q['x'], q['height'], -q['y']], heading=q['heading'], template=q['template'], placement_hex=q['placement_hex'])

    locks = {}
    grant = '03010000' + struct.pack('<I', KEY['identity']).hex()
    for c in LOCKS:
        recs = records('control', c)
        insert = [r for r in recs if r['kind'] == 4 and r['mode'] == 3]; take = [r for r in recs if r['kind'] == 4 and r['mode'] == 0]
        assert len(insert) == 1 and len(take) == 1 and insert[0]['held_identity'] == KEY['identity'], c
        insert, take = insert[0], take[0]
        assert '020100001800' in insert['commands'] and not any(x.startswith(grant) for x in insert['commands']), c
        assert sum(x.startswith(grant) for x in take['commands']) == 1 and '020100001800' not in take['commands'], c
        store, empty_value = storage(insert['predicate_expression']); store2, loaded_value = storage(take['predicate_expression'])
        assert store == store2 and empty_value != loaded_value, c
        # The storage write in each group moves it to the other predicate value (op16 for owner state, op198 for locals).
        write = (lambda v: '1010%02x00%02x00' % (c, v)) if store['kind'] == 'owner_state' else (lambda v: 'c6000000%02x%02x' % (store['index'], v))
        assert write(loaded_value) in insert['commands'] and write(empty_value) in take['commands'], c
        locks[str(c)] = dict(place(statics[c]), storage=store, loaded_value=loaded_value, initial_loaded=loaded_value == 0,
                             insert=insert, take=take, other_records=[r for r in recs if r['kind'] != 4])
    assert [int(c) for c, l in locks.items() if l['initial_loaded']] == [87]
    assert all(l['storage'] == dict(kind='local', index=i) for l, i in [(locks['78'], 18), (locks['114'], 2), (locks['141'], 4), (locks['142'], 3), (locks['144'], 5)])

    # Effects classified from the records (op1 movable position, op5 selector, op9 property, op6 event, op16 state).
    l140 = locks['140']
    assert l140['insert']['commands'][:2] == ['012035006400', '102035000100'] and '012033006400' in l140['insert']['commands']
    assert l140['take']['commands'][:2] == ['012035000000', '102035000000'] and '012033000000' in l140['take']['commands']
    l113 = locks['113']
    assert all('05%02x%02x000100' % (0x10, s) in l113['insert']['commands'] and '05%02x%02x000000' % (0x10, s) in l113['take']['commands'] for s in SCONCES)
    sconces = {}
    for s in SCONCES:
        recs = records('control', s)
        sel = {r['value']: r['commands'] for r in recs if r['kind'] == 3}
        assert sel == {0: ['1010%02x000000' % s], 1: ['1010%02x000100' % s]}, s  # selector endpoint writes owner state
        use = {r['mode']: r for r in recs if r['kind'] == 4}
        assert use[3]['predicate_expression']['raw'] == '0005000001' and use[3]['held_identity'] == 0xddc02377  # 57b-Fire brnt
        assert use[3]['commands'] == ['020100001800', '030100007791b8e701000000']
        # Control134 alone has no empty-hand record in the source.
        assert (s == 134) == (0 not in use) and all(use[0]['commands'] == ['130100001000010005ec'] for _ in [0] if 0 in use)
        sconces[str(s)] = dict(place(statics[s]), recharge=use[3], empty_hand=use.get(0))
    l114 = locks['114']
    assert '012037006400' in l114['insert']['commands'] and '012037000000' in l114['take']['commands']
    panel_recs = records('movable', 55)
    give = next(r for r in panel_recs if r['kind'] == 4 and r['mode'] == 0); back = next(r for r in panel_recs if r['kind'] == 4 and r['mode'] == 3)
    assert give['predicate_expression']['raw'] == '0005000000' and give['commands'][0] == '03010000' + struct.pack('<I', SS1['identity']).hex() + '01000000'
    assert '102037000100' in give['commands'] and back['predicate_expression']['raw'] == '0005000001' and back['held_identity'] == SS1['identity']
    assert '102037000000' in back['commands'] and '020100001800' in back['commands']

    blob, base, count, names = definitions()
    assert names[KEY['definition']] == KEY['name'] and u32(blob, base + KEY['definition'] * 91 + 24) == KEY['identity']
    ss1_def = next(i for i in range(count) if u32(blob, base + i * 91 + 24) == SS1['identity']); assert names[ss1_def] == SS1['name']
    SS1['definition'] = ss1_def
    result = dict(version=1, source=area['source'], key=KEY, ss1=SS1, locks=locks, sconces=sconces,
                  panel=dict(movable=55, **place(movables[55]), give=give, put_back=back,
                             flanks={str(m): place(movables[m]) for m in (80, 81)}),
                  gallery=dict(lever=53, grate=51, lever_position=place(movables[53])['position'], grate_position=place(movables[51])['position']),
                  initial_loaded=[87],
                  not_hosted={'78': 'control106 panel texture/animated motion (pose swap only); opcode204 region1237 material select; command sound',
                              '113': 'props276-279 event1/2, prop297 property16, prop126 effect; sconce recharge (57b-Fire brnt to 57a-Fire crstl) and empty-hand op19',
                              '114': 'opcode197 region504 marker3/5, locals1/2/27 bookkeeping, movables80/81 flank motion, movable55 animated travel',
                              '140': 'movable78 reset, prop125 effect',
                              'kind8': 'own animation endpoint chains (op 0x18), controls159-161 events without observable records',
                              'effect_props': 'transient effect props109-125 (op9 property3 on insert, property2 at the animation end/take)'},
                  scope='Direct source records. Reach/aim, presentation, effect pulse and immediate (untimed) animation endpoints are modern adapters.')
    a.output.parent.mkdir(parents=True, exist_ok=True); a.output.write_text(json.dumps(result, indent=1) + '\n')
    if a.passage_output:
        passage78(locks['78'], records('prop', 81), statics, a.passage_output)
    if a.icon_dir:
        for item in (KEY, SS1): icon(item['definition'], a.icon_dir / item['icon'])
    print(f"PASS museum key locks: {len(locks)} locks, {len(sconces)} sconces, initial loaded {result['initial_loaded']}, SS1 definition {ss1_def}")


PASSAGE_REGIONS = {1237: (0x4d5, 30), 1477: (0x5c5, 80)}
REVIEW = dict(geometry='museum_geometry_20260913/geometry.json', presets='museum_materials_20260913/floor_presets.json',
              materials='museum_capture_20260913/materials', arrival='museum_capture_20260913/arrival_verified.json',
              surface_setup='museum_materials_20260913/surface_setup.json', rotation_table='draracle_rotation_table_2026-09-11/rotation_table.bin')


def passage78(lock, prop81, statics, out):
    """Control78's insert and take groups both send prop81 property21; prop81's two kind6/event20 records (owner state 0/1)
    toggle its state, move control106 (op18) and set opcode196 floor targets of regions1237/1477 to 0 (open) or back to
    their loaded heights 30/80 (closed). The open variant is the unchanged museum_review builder run with only those two
    floors lowered; faces are diffed against the reproduced shipped museum.json."""
    import subprocess, tempfile
    assert lock['insert']['commands'][1] == '090351001500' and lock['take']['commands'][0] == '090351001500'
    ev = {r['predicate_expression']['raw']: r for r in prop81 if r['kind'] == 6 and r['value'] == 20}
    assert set(ev) == {'0005000000', '0005000001'}
    opening, closing = ev['0005000000']['commands'], ev['0005000001']['commands']
    for region, (word, height) in PASSAGE_REGIONS.items():
        assert 'c490%04x0000000f00000000' % struct.unpack('>H', struct.pack('<H', word))[0] in opening
        assert 'c490%04x%04x000f00000000' % (struct.unpack('>H', struct.pack('<H', word))[0], struct.unpack('>H', struct.pack('<H', height))[0]) in closing
    assert '100351000100' in opening and '100351000000' in closing
    move = lambda c: dict(x=struct.unpack_from('<h', bytes.fromhex(c), 4)[0], y=struct.unpack_from('<h', bytes.fromhex(c), 6)[0],
                          heading=struct.unpack_from('<H', bytes.fromhex(c), 12)[0], raw=c)
    poses = dict(open=move(opening[0]), closed=move(closing[0])); assert opening[0].startswith('12106a00') and closing[0].startswith('12106a00')
    lol2_out = MAP.parents[1]; shipped = ROOT / 'assets/lol2/generated/museum_review/museum.json'
    def build(geometry, arrival, folder):
        args = ['python3', '-B', str(ROOT / 'tools/build_museum_review.py'), '--game-root', str(GAME), '--geometry', str(geometry),
                '--presets', str(lol2_out / REVIEW['presets']), '--materials', str(lol2_out / REVIEW['materials']), '--arrival', str(arrival),
                '--surface-setup', str(lol2_out / REVIEW['surface_setup']), '--rotation-table', str(lol2_out / REVIEW['rotation_table']), '--out', str(folder)]
        subprocess.run(args, check=True, cwd=ROOT / 'tools', capture_output=True)
        return json.loads((folder / 'museum.json').read_text())
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp); geometry = lol2_out / REVIEW['geometry']; arrival = lol2_out / REVIEW['arrival']
        base = build(geometry, arrival, tmp / 'base')
        assert (tmp / 'base/museum.json').read_bytes() == shipped.read_bytes(), 'museum_review reproduction differs from shipped museum.json'
        g = json.loads(geometry.read_text())
        for r in g['regions']:
            if r['id'] in PASSAGE_REGIONS:
                assert r['floor_base'] == PASSAGE_REGIONS[r['id']][1]; r['floor_base'] = 0; r['floor_corners'] = [0] * len(r['floor_corners'])
        (tmp / 'geometry.json').write_text(json.dumps(g))
        arr = json.loads(arrival.read_text()); arr['geometry_sha256'] = hashlib.sha256((tmp / 'geometry.json').read_bytes()).hexdigest()
        (tmp / 'arrival.json').write_text(json.dumps(arr))
        opened = build(tmp / 'geometry.json', tmp / 'arrival.json', tmp / 'open')
    key = lambda f: json.dumps(f, sort_keys=True)
    base_keys = [key(f) for f in base['faces']]; open_keys = {key(f) for f in opened['faces']}
    closed_only = [i for i, k in enumerate(base_keys) if k not in open_keys]
    open_only = [f for f in opened['faces'] if key(f) not in set(base_keys)]
    assert closed_only and open_only and all(base['faces'][i]['material'] in base['materials'] or base['faces'][i]['material'] in ('shell', 'unresolved') for i in closed_only)
    missing = sorted({f['material'] for f in open_only} - set(base['materials']) - {'shell', 'unresolved'})
    assert not missing, missing
    panel = statics[106]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(dict(version=1, shipped_sha256=hashlib.sha256(shipped.read_bytes()).hexdigest(), regions=sorted(PASSAGE_REGIONS),
                                   closed_face_indices=closed_only, closed_faces=[base['faces'][i] for i in closed_only], open_faces=open_only,
                                   prop81=dict(opening=opening, closing=closing), control106=dict(position=[panel['x'], panel['height'], -panel['y']],
                                   heading=panel['heading'], template=panel['template'], poses=poses)), indent=1) + '\n')
    print('passage78: closed-only', len(closed_only), 'open-only', len(open_only), 'control106 poses', poses['closed']['x'], poses['closed']['y'], '->', poses['open']['x'], poses['open']['y'])


def icon(definition, path):
    from PIL import Image
    from prepare_hive_wax import entry, sections, rgb_palette, decode_rows
    defs = entry('GLOBAL.MIX', 3984507021); base, count = u32(defs, 4), u32(defs, 0x34)
    state = base + count * 91 + 4; view = state + u32(defs, state - 4) * 16 + 4
    state_index = view_index = 0; resource = None
    for index in range(count):
        rec = defs[base + index * 91:][:91]
        for sel in range(rec[46] + rec[47]):
            views = max(1, struct.unpack_from('<b', defs, state + state_index * 16 + 13)[0])
            if sel == 0 and index == definition: resource = struct.unpack_from('<h', defs, view + view_index * 12)[0]
            state_index += 1; view_index += views
    graphics = entry('LOCAL.MIX', 4018716831); sec = sections(graphics); palette = rgb_palette(graphics[u32(graphics, 4):][:768], 6)
    desc = struct.unpack_from('<6H11I', graphics, sec[2] + resource * 56)
    width, height, pixels, _ = decode_rows(graphics[sec[3] + desc[7]:][:desc[12]], allow_special=True)
    rgba = bytes(c for px in pixels for c in (*palette[px * 3:px * 3 + 3], 0 if px in (0, 1) else 255))
    path.parent.mkdir(parents=True, exist_ok=True); Image.frombytes('RGBA', (width, height), rgba).save(path)
    print('icon', path.name, 'resource', resource, (width, height))


if __name__ == '__main__':
    main()
