#!/usr/bin/env python3
"""Pin the Hive Reaver alcove (control121) with its ceiling-collapse trap, and the Amber vein (control123).

control121 (template29, selector0 sword in the wall / selector1 empty):
  kind4 mode0 state0 g6844: selector1, state1, op3 "18-Reaver of GO" (identity 0xF470CF20, property4).
  kind3 value1 (selector1 reached) g6874: state2, op14 sub5 (reset timer0 to a fresh duration).
  kind2 timer0 (flag 0x10 seconds, range 5..10, initially running) at state2 g6894: op196 region365 floor -> -234
      (speed5), op14 sub4 stops the timer.
Region kind11 records (movement events, dispatched by F2FC0; event = floor up/down start 0/1, end 4/5, ceiling up/down
start 2/3, end 6/7) chain the collapse: 365 floor start -> g262 (364 floor -> -185), 364 floor end -> g222 (364 ceiling
-> -185), 364 ceiling end -> g250 (365 ceiling -> -234), 365 ceiling start -> g408 (366 ceiling -> -235), 366 start ->
g420 (367), 367 end -> g446 (368), 368 end -> g474 (369 -> -200), 369 end -> g532 (370 -> -185), 370 end -> g560
(op204 region materials, props property2).
op196 (handler 64DDC): u16 region, s16 target, byte6 bit0 ceiling / 0 floor (bit3 relative), byte7 speed.
control123 (template27, four selector textures): kind4 mode0 state0/1/2 -> one "110-Amber" each (identity 0x7F859FB9),
  states 0->1->2->5 (selector 3 at 5; state2 also enables and resets the timer). kind2 timer0 (flag 0x10, 32..144 s,
  initially running) at state5: stop, selector2, state2 (one Amber regrows).
Usage: prepare_hive_reaver_amber.py --output scripts/lol2/hive_reaver_amber_source.json --asset-dir assets/lol2/generated/hive_reaver_amber
"""
import argparse, hashlib, json, re, shutil, struct, sys
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate
from verify_hive_executioner import GAME

ROOT = Path(__file__).resolve().parents[1]
ALLMAP = Path('/home/bob/lol2_out/all_maps_20260922/L5_HC')
GEOMETRY = Path('/home/bob/lol2_out/hive_geometry_20260914/geometry.json')
REAVER = dict(identity=0xF470CF20, name='18-Reaver of GO', definition=17, handler=18)
AMBER = dict(identity=0x7F859FB9, name='110-Amber', definition=112, handler=0)
CHAIN = {(364, 4): 222, (364, 7): 250, (365, 0): 262, (365, 3): 408, (366, 3): 420, (367, 7): 446, (368, 7): 474, (369, 7): 532, (370, 7): 560}
REGIONS = list(range(364, 372))


def grant(item, prop=4):
    return '03010000' + struct.pack('<I', item['identity']).hex() + '%02x000000' % prop


def records(owners, streams, arc, table, kind, n):
    out = []
    for r in [r for r in owners if r['owner_kind'] == kind and r['owner'] == n]:
        out.append(dict(kind=r['event'], value=r['value'], group=r['group'], predicate=predicate(table, r['predicate'])['raw'] if r['predicate'] is not None else None,
                        commands=[c['raw_hex'] for c in streams[r['stream']][r['group']]], raw=arc[r['archive_offset']:r['archive_offset'] + arc[r['archive_offset']]].hex()))
    return out


def timer(raw_hex):
    b = bytes.fromhex(raw_hex)
    assert len(b) == 10 and b[1] == 2 and b[4] == 0x10, raw_hex
    lo, hi = sorted((b[6], b[7]))
    return dict(flags=b[4], initially_running=not (b[5] & 1), range_seconds=[lo, hi], counter_ticks=struct.unpack_from('<H', b, 8)[0])


def mover(cmd):
    b = bytes.fromhex(cmd)
    assert b[0] == 0xC4 and b[1] == 0x90 and len(b) == 12 and not (b[6] & 0x08), cmd
    region, target = struct.unpack_from('<Hh', b, 2)
    return dict(region=region, surface='ceiling' if b[6] & 1 else 'floor', target=target, speed=b[7])


def faces(assemblies, n, out_dir, mats):
    rows = []
    for f in assemblies['faces'] + assemblies['state_faces']:
        if f['source_index'] != n: continue
        rid = f['resource_id']; name = 'm%04d.png' % rid
        src = mats / ('material_%04d' % rid) / 'mip_0_palette.png'
        assert src.exists(), src
        shutil.copyfile(src, out_dir / name)
        rows.append(dict(points=f['points'], uv=f['uv'], material=name, child_mask=f['child_mask'], resource_id=rid))
    return rows


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True); p.add_argument('--asset-dir', type=Path, required=True)
    p.add_argument('--materials', type=Path, default=None, help='current lol2.map_materials export of L5_HC (exported when absent)')
    a = p.parse_args(); a.asset_dir.mkdir(parents=True, exist_ok=True)
    area, arc, entry, raw, owners, streams = source_area('L5_HC')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    # control121
    rs = records(owners, streams, arc, table, 'control', 121)
    use = [r for r in rs if r['kind'] == 4]; sel = [r for r in rs if r['kind'] == 3]; tim = [r for r in rs if r['kind'] == 2]
    assert len(rs) == 3 and len(use) == len(sel) == len(tim) == 1
    assert use[0]['predicate'] == '0005000000' and use[0]['commands'] == ['051079000100', '101079000100', grant(REAVER)], use
    assert sel[0]['value'] == 1 and sel[0]['predicate'] is None and sel[0]['commands'] == ['101079000200', '0e10790005000000'], sel
    assert tim[0]['predicate'] == '0005000002' and tim[0]['commands'] == ['c4906d0116ff000500000000', '0e10790004000000'], tim
    reaver_timer = timer(tim[0]['raw']); assert reaver_timer['range_seconds'] == [5, 10] and reaver_timer['initially_running']
    # Region kind11 movement-event records (F2FC0); collect_owners does not parse these.
    found = {}
    for m in re.finditer(rb'\x08\x0b', raw):
        b = raw[m.start():m.start() + 8]
        g, reg = struct.unpack_from('<HH', b, 2)
        if reg in REGIONS: found[(reg, b[6])] = g
    assert found == CHAIN, found
    chain = []
    for (reg, ev), g in sorted(CHAIN.items(), key=lambda kv: kv[1]):
        cmds = [c['raw_hex'] for c in streams[0][g]]
        moves = [mover(c) for c in cmds if c.startswith('c4')]
        others = [c for c in cmds if not c.startswith('c4')]
        assert all(c[:2] in ('14', '09', 'd0', 'cc') for c in others), (g, others)
        chain.append(dict(region=reg, event=ev, group=g, movers=moves, materials=[c for c in others if c.startswith('cc')], not_hosted=[c for c in others if not c.startswith('cc')]))
    flat = {(m['region'], m['surface']): m for c in chain for m in c['movers']}
    assert {k: (v['target'], v['speed']) for k, v in flat.items()} == {(364, 'ceiling'): (-185, 20), (365, 'ceiling'): (-234, 20), (364, 'floor'): (-185, 20), (366, 'ceiling'): (-235, 4),
                                                                      (367, 'ceiling'): (-235, 20), (368, 'ceiling'): (-235, 20), (369, 'ceiling'): (-200, 20), (370, 'ceiling'): (-185, 20)}, flat
    # control123
    rs = records(owners, streams, arc, table, 'control', 123)
    use = {r['predicate']: r for r in rs if r['kind'] == 4}; tim = [r for r in rs if r['kind'] == 2]
    assert set(use) == {'0005000000', '0005000001', '0005000002'} and len(tim) == 1 and len(rs) == 4
    snd = '14107b00ce0280000a14'
    assert use['0005000000']['commands'] == [snd, grant(AMBER), '05107b000100', '10107b000100']
    assert use['0005000001']['commands'] == [snd, grant(AMBER), '05107b000200', '10107b000200']
    assert use['0005000002']['commands'] == [snd, grant(AMBER), '05107b000300', '10107b000500', '0e107b0003000000', '0e107b0005000000']
    assert tim[0]['predicate'] == '0005000005' and tim[0]['commands'] == ['0e107b0004000000', '05107b000200', '10107b000200']
    amber_timer = timer(tim[0]['raw']); assert amber_timer['range_seconds'] == [32, 144] and amber_timer['initially_running']
    # Items.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_museum_key_locks import definitions, icon
    from build_game_atlas import u32
    blob, base, n, names = definitions()
    for item in (REAVER, AMBER):
        d = blob[base + item['definition'] * 91:base + (item['definition'] + 1) * 91]
        assert names[item['definition']] == item['name'] and u32(d, 24) == item['identity'] and d[0x42] == item['handler'], item
    icon(REAVER['definition'], a.asset_dir / 'reaver.png'); icon(AMBER['definition'], a.asset_dir / 'amber.png')
    # Assemblies and materials (current exporter: the 2026-09-22 export rejected material27, flags 0x80E1).
    mats = a.materials
    if mats is None:
        from lol2.map_materials import export_materials
        mats = ROOT / 'tmp/hive_reaver_amber_materials'
        export_materials(GAME, 'L5_HC', mats)
    assemblies = json.loads((ALLMAP / 'static_assemblies/movables.json').read_text())
    assert assemblies['source']['sha256'] == area['source']['sha256']
    place = {q['source_index']: q for q in assemblies['placements']}
    controls = {}
    for c, template, masks in [(121, 29, {1, 2}), (123, 27, {1, 2, 4, 8})]:
        q = place[c]; assert q['template'] == template
        rows = faces(assemblies, c, a.asset_dir, mats)
        assert {r['child_mask'] for r in rows} == masks, (c, rows)
        controls[str(c)] = dict(position=[q['x'], q['height'], -q['y']], heading=q['heading'], template=template, faces=rows)
    # Corridor geometry for the moving surfaces.
    g = json.loads(GEOMETRY.read_text()); staged = json.loads((ROOT / 'assets/lol2/generated/hive_review/hive.json').read_text())
    regions = {}
    for r in REGIONS:
        rec = g['regions'][r]
        poly = [[g['vertices_fixed'][v][0] / 65536, -g['vertices_fixed'][v][1] / 65536] for v in rec['vertex_indices']]
        mat = {f['kind']: f['material'] for f in staged['faces'] if f['region'] == r}
        assert rec['floor_base'] == -235 and rec['ceiling_base'] == -107 and not rec['floor_slope'], r
        regions[str(r)] = dict(polygon=poly, floor=rec['floor_base'], ceiling=rec['ceiling_base'], neighbors=rec['neighbors'], materials=mat)
    result = dict(version=1, source=area['source'], reaver=dict(item=REAVER, timer=reaver_timer, use_group=6844, selector_group=6874, timer_group=6894,
                                                                     trigger=mover('c4906d0116ff000500000000')),
                  amber=dict(item=AMBER, timer=amber_timer), chain=chain, regions=regions, controls=controls,
                  speed_units_per_second_per_byte=2.5,
                  adapters=['E at an aimed control in reach is the kind4 mode0 producer (Hive pickups go straight to inventory)',
                            'timer durations use the midpoint of each source range (Reaver 7.5 s; Amber 88 s)',
                            'surface speed = byte7 x 2.5 units/s (assumes [0x22C54] = 16.16 ticks at 60/s; not traced)',
                            'a ceiling stops above a player standing under it (native B861C blocks movement on occupant clearance; damage not established)',
                            'op204 region material writes, op9 prop properties, op208 and op20 sounds are not hosted',
                            'equipping the Reaver (handler18 event10) sets player byte 0x2270E bit3; no reader traced, so it is a plain weapon'],
                  scope='Direct source records; the region kind11 chain is asserted byte for byte.')
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS hive reaver/amber: chain %d groups, %d corridor regions, controls %s' % (len(chain), len(regions), {k: len(v['faces']) for k, v in controls.items()}))


if __name__ == '__main__':
    main()
