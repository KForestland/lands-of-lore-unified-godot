#!/usr/bin/env python3
"""Pin the native collision boxes of one map's static assemblies (scripts/lol2/static_collision_AREA.json).

Native rule (LOLG.DAT):
  AE990 (object base init) copies placement word8 into obj+0x14; the pair scan 5B974 only tests objects with bit 0x80
  set (and 0x2000000 clear). 5BD90 then reads the template (60-byte record, [0x22d4c] + 60*index) byte 0x2D: &3 == 0
  no collision, 1 a special routine (B276C), 2 an oriented box with half-sizes byte 0x2F / 2 (x) and byte 0x30 / 2
  (depth), rotated by the placement heading and grown by the mover radius (byte 0x31 is the height). Mode 3 goes
  5C1F5/5C3B6 -> 5BFEC and tests each child record (stride 0x3C, fields +0x30..+0x3B by child type +0x3B) as its own
  box; the whole-template size is then only an outer bound, and the child records (mask, signed x/y bounds, height,
  type) are written as "children". Type 1 children (e.g. L1_DC 156 child 12, not drawn by the type0 exporter) are
  included; type 2 (other fields) is refused. Codex OPUS_CAVE156_CHILD_COLLISION.
Every solid placement is listed (scripted = has event records or is a kind-16 command target), owned ones included (hosts such as the shrine doors and the rubble blocks reuse it).
Assemblies of mode 1 are refused (none occur in L1_DC / L3_DH). The runtime (static_assemblies.gd) builds boxes for
non-owned solids at least MIN_HEIGHT tall; lower ones are left walkable (modern adapter, docs/DEVIATIONS.md).
Usage: prepare_static_collision.py --game GAME --re-root RE --area L1_DC|L3_DH|L4_HJ|L5_HC|L7_DH|L8_SJ|L10_DC|L13_RC|L16_CA|L19_BC|L9_DR|L12_CM|L14_HT|L17_HC|L20_BB [--project PROJECT]
"""
import argparse, hashlib, json, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AREAS = ('L1_DC', 'L3_DH', 'L4_HJ', 'L5_HC', 'L7_DH', 'L8_SJ', 'L10_DC', 'L13_RC', 'L16_CA', 'L19_BC', 'L9_DR', 'L12_CM', 'L14_HT', 'L17_HC', 'L20_BB')


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--re-root', type=Path, required=True)
    p.add_argument('--area', required=True, choices=AREAS)
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from lol2 import map_materials
    exe = (a.game / 'LOLG.DAT').read_bytes()
    # The collision tests the rule above depends on.
    assert exe[0xae9d8 + 0x37000:0xae9e3 + 0x37000].hex() == '668b4208894314806316ef', 'AE990 flag copy changed'
    assert exe[0x5b9d5 + 0x37000:0x5b9db + 0x37000].hex() == '81e280000000', '5B974 solid test changed'
    with tempfile.TemporaryDirectory(prefix='static-collision-') as temp:
        h = Path(temp)
        map_materials.export_materials(a.game.resolve(), a.area, h / 'materials')
        subprocess.run([sys.executable, str(ROOT / 'tools/export_map_movables.py'), '--game-root', str(a.game.resolve()),
                        '--material-root', str(h / 'materials'), '--re-root', str(a.re_root.resolve()), '--tools-root', str(ROOT / 'tools'),
                        '--area', a.area, '--placement-kind', 'static_assembly', '--out', str(h / 'assemblies')],
                       check=True, stdout=subprocess.DEVNULL)
        data = json.loads((h / 'assemblies/movables.json').read_text())
    # Scripted assemblies (own event records, or the target of any kind-16 command such as op18 moves / op9 unlinks)
    # are left to their hosts: their position or link state changes at run time.
    from verify_actor_item_grants import source_area
    _, _, _, _, owners, streams = source_area(a.area, a.game.resolve())
    scripted = {o['owner'] for o in owners if o['owner_kind'] == 'control'}
    for stream in streams:
        for commands in stream.values():
            for c in commands:
                raw = bytes.fromhex(c['raw_hex'])
                if len(raw) >= 4 and raw[1] == 0x10: scripted.add(int.from_bytes(raw[2:4], 'little'))
    templates = data['source_templates']
    boxes = {}
    for pl in data['placements']:
        raw = bytes.fromhex(pl['placement_hex'])
        word = int.from_bytes(raw[8:10], 'little')
        if not word & 0x80: continue
        t = bytes.fromhex(templates[pl['template']]['raw_hex'])
        mode = t[45] & 3
        assert mode != 1, ('mode 1 (B276C) not supported', pl['source_index'])
        if mode == 0: continue
        boxes[str(pl['source_index'])] = dict(template=pl['template'], flags=word, mode=mode, width=t[47], depth=t[48], height=t[49],
                                              x=pl['x'], y=pl['y'], h=pl['height'], heading=pl['heading'],
                                              scripted=pl['source_index'] in scripted)
        if mode == 3:
            # 5BFEC: one box per child record (+0x30 mask, +0x34..+0x37 signed x/y bounds, +0x38/+0x39 height, +0x3B type).
            # Type 2 reads other fields (5C013/5C038/5C058/5C07B); none occur here, so refuse rather than guess.
            children = templates[pl['template']]['children']
            assert all(c['type_byte'] != 2 for c in children), ('mode-3 type2 child not supported', pl['source_index'])
            boxes[str(pl['source_index'])]['children'] = [dict(child=c['index'], type=c['type_byte'], mask=c['mask'], bounds=c['bounds'])
                                                          for c in children]
    out = dict(version=1, area=a.area, source=dict(executable_sha256=hashlib.sha256(exe).hexdigest(), movables=data.get('source')),
               rule='solid = placement word8 & 0x80; template byte0x2D&3 != 0 -> oriented box width=byte0x2F, depth=byte0x30, '
                    'height=byte0x31 from the placement height, rotated by heading (0..65535 = full turn); mode 3: one such box per '
                    'child record (bounds bytes 0x34..0x39, admitted by mask bit of the assembly mode)',
               boxes=boxes)
    path = a.project / f'scripts/lol2/static_collision_{a.area}.json'
    path.write_text(json.dumps(out, indent=1) + '\n')
    print(f'PASS static collision {a.area}: {len(boxes)} solid boxes, {sum(b["scripted"] for b in boxes.values())} scripted')


if __name__ == '__main__':
    main()
