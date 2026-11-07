#!/usr/bin/env python3
"""Rebuild one map's original static assemblies for the generic renderer (scripts/lol2/static_assemblies.gd).

Every placement of kind static_assembly is exported with tools/export_map_movables.py (initial-mode faces plus the
other-mode state faces of the same child records). Assemblies listed in scripts/lol2/static_assembly_owners.json are
drawn by their feature hosts and are skipped. The build refuses if any other assembly face coincides with a face in
that area's host packs, so nothing is drawn twice.

Output: PROJECT/assets/lol2/generated/static_assemblies/AREA/assemblies.json and one image per material:
  indexed areas (Cave): mip_0_indices.png for the indexed surface shader;
  colour areas (Museum): mip_0_palette.png (RGBA, index 0 already transparent).
cutout = the material's palette image has transparent pixels. No collision: the placement bytes are kept for a later
collision pass. Type1 (attached prop) children are not exported by this exporter and are listed under open_children.

Usage: prepare_static_assemblies.py --game GAME --re-root RE --area L1_DC|L3_DH|L4_HJ|L5_HC|L8_SJ|L10_DC|L13_RC|L16_CA|L19_BC [--project PROJECT]
"""
import argparse, hashlib, json, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AREAS = {
    'L20_BB': {'render': 'colour', 'review': 'assets/lol2/generated/maps/L20_BB/area.json'},
    'L17_HC': {'render': 'colour', 'review': 'assets/lol2/generated/maps/L17_HC/area.json'},
    'L14_HT': {'render': 'colour', 'review': 'assets/lol2/generated/maps/L14_HT/area.json'},
    'L12_CM': {'render': 'colour', 'review': 'assets/lol2/generated/maps/L12_CM/area.json'},
    'L1_DC': {'render': 'indexed', 'review': None},
    'L3_DH': {'render': 'colour', 'review': 'assets/lol2/generated/museum_review/museum.json'},
    'L4_HJ': {'render': 'colour', 'review': 'assets/lol2/generated/jungle_review/jungle.json'},
    'L5_HC': {'render': 'colour', 'review': 'assets/lol2/generated/hive_review/hive.json'},
    'L9_DR': {'render': 'colour', 'review': 'assets/lol2/generated/dragon_level/area.json'},
    'L8_SJ': {'render': 'colour', 'review': 'assets/lol2/generated/darker_jungle/area.json'},
    'L10_DC': {'render': 'colour', 'review': 'assets/lol2/generated/maps/L10_DC/area.json'},
    'L13_RC': {'render': 'colour', 'review': 'assets/lol2/generated/maps/L13_RC/area.json'},
    'L16_CA': {'render': 'colour', 'review': 'assets/lol2/generated/maps/L16_CA/area.json'},
    'L19_BC': {'render': 'colour', 'review': 'assets/lol2/generated/maps/L19_BC/area.json'},
}
OWNERS = 'scripts/lol2/static_assembly_owners.json'


def sha(raw): return hashlib.sha256(raw).hexdigest()


def signature(points): return tuple(sorted(tuple(round(float(c)) for c in p) for p in points))


def pack_signatures(path: Path) -> set:
    found = set()
    files = [path] if path.is_file() else sorted(path.rglob('*.json'))
    for f in files:
        try: data = json.loads(f.read_text())
        except (ValueError, UnicodeDecodeError): continue
        stack = [data]
        while stack:
            o = stack.pop()
            if isinstance(o, dict):
                p = o.get('points')
                if isinstance(p, list) and len(p) in (3, 4) and all(isinstance(q, list) and len(q) == 3 for q in p):
                    found.add(signature(p))
                stack.extend(o.values())
            elif isinstance(o, list): stack.extend(o)
    return found


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--re-root', type=Path, required=True)
    p.add_argument('--area', required=True, choices=sorted(AREAS))
    p.add_argument('--project', type=Path, default=ROOT)
    a = p.parse_args()
    project = a.project.resolve()
    config = AREAS[a.area]
    owners_doc = json.loads((project / OWNERS).read_text())['areas'][a.area]
    owned = {int(k) for k in owners_doc['owners']}
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from lol2 import map_materials
    from PIL import Image
    with tempfile.TemporaryDirectory(prefix='static-assemblies-') as temp:
        h = Path(temp)
        map_materials.export_materials(a.game.resolve(), a.area, h / 'materials')
        subprocess.run([sys.executable, str(ROOT / 'tools/export_map_movables.py'), '--game-root', str(a.game.resolve()),
                        '--material-root', str(h / 'materials'), '--re-root', str(a.re_root.resolve()), '--tools-root', str(ROOT / 'tools'),
                        '--area', a.area, '--placement-kind', 'static_assembly', '--out', str(h / 'assemblies')],
                       check=True, stdout=subprocess.DEVNULL)
        data = json.loads((h / 'assemblies/movables.json').read_text())
        materials_root = Path(data['materials_root'])
        hosted = set()
        for pack in owners_doc['host_packs']:
            path = project / pack
            if not path.exists(): raise SystemExit(f'Host pack missing: {pack}')
            hosted |= pack_signatures(path)
        review = pack_signatures(project / config['review']) if config['review'] else set()
        placements = {x['source_index']: x for x in data['placements']}
        unknown_owned = owned - set(placements)
        if unknown_owned: raise SystemExit(f'Owner list names absent assemblies: {sorted(unknown_owned)}')
        faces = [f for f in data['faces'] if f['source_index'] not in owned]
        states = [f for f in data['state_faces'] if f['source_index'] not in owned]
        clashes = sorted({f['source_index'] for f in faces if signature(f['points']) in hosted})
        if clashes: raise SystemExit(f'Unlisted assemblies coincide with hosted faces: {clashes}')
        stateful = sorted({f['source_index'] for f in states})
        staged = h / 'staged'; staged.mkdir()
        materials, images = {}, {}
        for f in faces + states:
            name = f['material']
            if name in materials: continue
            palette = materials_root / name
            source = palette if config['render'] == 'colour' else palette.with_name(palette.name.replace('_palette.png', '_indices.png'))
            alpha = Image.open(palette).convert('RGBA').getchannel('A').getextrema()[0]
            dest = f"material_{int(f['resource_id']):04d}.png"
            raw = source.read_bytes(); (staged / dest).write_bytes(raw)
            materials[name] = {'image': dest, 'resource': int(f['resource_id']), 'cutout': alpha < 255}
            images[dest] = sha(raw)
        rows = []
        for f in faces + states:
            rows.append({'assembly': f['source_index'], 'template': f['template'], 'child': f['child'], 'mask': f['child_mask'],
                         'initial': not f.get('hidden', False), 'material': materials[f['material']]['image'],
                         'points': f['points'], 'uv': f['uv']})
        drawn = sorted({f['source_index'] for f in faces})
        result = {
            'version': 1, 'area': a.area, 'render': config['render'], 'source': data['source'],
            'faces_sha256': sha(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()),
            'counts': {'placements': len(placements), 'owned': len(owned), 'drawn': len(drawn), 'stateful': len(stateful),
                       'initial_faces': len(faces), 'state_faces': len(states), 'materials': len(materials),
                       'without_faces': len(set(placements) - owned - set(drawn) - set(stateful))},
            'owned': {str(k): owners_doc['owners'][str(k)] for k in sorted(owned)},
            'drawn': drawn, 'stateful': stateful,
            'review_coincident': sorted({f['source_index'] for f in faces if signature(f['points']) in review}),
            'placements': {str(k): {'template': v['template'], 'x': v['x'], 'y': v['y'], 'height': v['height'], 'heading': v['heading'],
                                    'placement_hex': v['placement_hex']} for k, v in sorted(placements.items()) if k not in owned},
            'open_children': [{k: i[k] for k in ('source_index', 'template', 'child', 'child_type', 'reason')} for i in data['issues']],
            'materials': {v['image']: {'resource': v['resource'], 'cutout': v['cutout'], 'sha256': images[v['image']]} for v in materials.values()},
            'faces': rows,
            'scope': 'Original static assemblies not owned by a feature host. Initial mode drawn; other-mode faces kept for '
                     'hosts that switch modes. No collision (placement bytes kept). Type1 children not exported.',
        }
        (staged / 'assemblies.json').write_text(json.dumps(result, indent=1) + '\n')
        out = project / 'assets/lol2/generated/static_assemblies' / a.area
        if out.exists(): shutil.rmtree(out)
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(staged, out)
    print(json.dumps({'area': a.area, **result['counts'], 'review_coincident': result['review_coincident'],
                      'open_children': len(result['open_children'])}))


if __name__ == '__main__':
    main()
