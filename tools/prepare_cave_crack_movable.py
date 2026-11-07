#!/usr/bin/env python3
"""Pin L1_DC movable 55, the rock slab with the crack-shaped hole in the scenic-guard doorway (owner R19 report
2026-10-17 10:51:27: "the crack in the wall ... should be more like a crack and not a square").

Source (L1_DC): the level wall of region 1108 has a rectangular doorway (x -184..-144, h 0..75, jambs 1589/1590).
The original fills it with movable placement 55:
  - template 50, one child (child92), 43 x 5 x 75;
  - native (-175, 7705, h 0), heading 28763;
  - placement word8 0x0181: bit 0x80 solid, no 0x1000 absence bit, so drawn and solid from the start;
  - both large faces use resource 284, a rock frame whose index-0 pixels form the irregular crack opening.
Movable 55 has no owner records and no command targets it (kind 0x20 #55), so it is plain scenery that no port host
drew. That left the square doorway visible and walkable.
Template byte0x2D&3 = 2: oriented box collision (5BD90), width 43 / depth 5 / height 75.
Output: PROJECT/assets/lol2/generated/cave_crack_movable/{movable.json, material_0284.png (indices)}.
Usage: prepare_cave_crack_movable.py --game GAME --re-root RE [--project PROJECT]
"""
import argparse, hashlib, json, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOVABLE = 55
PLACEMENT_HEX = '51ff191e5b70000081013405000000005c24f382141418830000000001006400320100010001000000'
TEMPLATE = 50
RESOURCE = 284


def sha(raw): return hashlib.sha256(raw).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--re-root', type=Path, required=True)
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from lol2 import map_materials
    from verify_actor_item_grants import source_area
    from PIL import Image
    _, arc, _, _, owners, streams = source_area('L1_DC', a.game.resolve())
    assert not [o for o in owners if o['owner_kind'] == 'movable' and o['owner'] == MOVABLE], 'movable 55 gained records'
    for stream in streams:
        for commands in stream.values():
            for c in commands:
                raw = bytes.fromhex(c['raw_hex'])
                assert not (len(raw) >= 4 and raw[1] == 0x20 and int.from_bytes(raw[2:4], 'little') == MOVABLE), 'command targets movable 55'
    with tempfile.TemporaryDirectory(prefix='cave-crack-') as temp:
        h = Path(temp)
        map_materials.export_materials(a.game.resolve(), 'L1_DC', h / 'materials')
        subprocess.run([sys.executable, str(ROOT / 'tools/export_map_movables.py'), '--game-root', str(a.game.resolve()),
                        '--material-root', str(h / 'materials'), '--re-root', str(a.re_root.resolve()), '--tools-root', str(ROOT / 'tools'),
                        '--area', 'L1_DC', '--placement-kind', 'movable', '--out', str(h / 'movables')],
                       check=True, stdout=subprocess.DEVNULL)
        data = json.loads((h / 'movables/movables.json').read_text())
        placement = [x for x in data['placements'] if x['source_index'] == MOVABLE]
        assert len(placement) == 1 and placement[0]['placement_hex'] == PLACEMENT_HEX and placement[0]['template'] == TEMPLATE, placement
        pl = placement[0]
        word = int.from_bytes(bytes.fromhex(PLACEMENT_HEX)[8:10], 'little')
        assert word & 0x80 and not word & 0x1000, hex(word)
        t = bytes.fromhex(data['source_templates'][TEMPLATE]['raw_hex'])
        assert (t[45] & 3, t[47], t[48], t[49]) == (2, 43, 5, 75), (t[45] & 3, t[47:50])
        faces = [f for f in data['faces'] if f['source_index'] == MOVABLE]
        assert len(faces) == 2 and all(f['resource_id'] == RESOURCE for f in faces), faces
        assert not [f for f in data.get('state_faces', []) if f['source_index'] == MOVABLE]
        assert not [x for x in data['issues'] if x.get('source_index') == MOVABLE]
        materials = Path(data['materials_root'])
        indices = (materials / f'material_{RESOURCE:04d}/mip_0_indices.png').read_bytes()
        palette = Image.open(materials / f'material_{RESOURCE:04d}/mip_0_palette.png').convert('RGBA')
        transparent = sum(1 for px in palette.getdata() if px[3] == 0)
        assert transparent > 0, 'resource 284 lost its cutout'
        out = a.project.resolve() / 'assets/lol2/generated/cave_crack_movable'
        staged = h / 'staged'; staged.mkdir()
        (staged / 'material_0284.png').write_bytes(indices)
        record = dict(version=1, area='L1_DC', movable=MOVABLE, template=TEMPLATE,
                      placement=dict(hex=PLACEMENT_HEX, x=pl['x'], y=pl['y'], h=pl['height'], heading=pl['heading'], word8=word),
                      box=dict(width=t[47], depth=t[48], height=t[49], shape_mode=t[45] & 3),
                      faces=[dict(points=f['points'], uv=f['uv'], resource=f['resource_id']) for f in faces],
                      material=dict(image='material_0284.png', resource=RESOURCE, cutout=True, sha256=sha(indices), transparent_pixels=transparent),
                      source=dict(archive_sha256=sha(arc)),
                      scope='Drawn as cave indexed surfaces (layer 2, cutout) plus one native box on the scenery layer. No records, so no behaviour.')
        (staged / 'movable.json').write_text(json.dumps(record, indent=1) + '\n')
        if out.exists(): shutil.rmtree(out)
        shutil.copytree(staged, out)
    print(f'PASS cave crack movable 55: 2 faces, resource 284 ({transparent} transparent pixels), box 43x5x75 heading {pl["heading"]}')


if __name__ == '__main__':
    main()
