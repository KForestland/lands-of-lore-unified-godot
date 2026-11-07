#!/usr/bin/env python3
"""Rebuild the Act 1 Dark Halls (L7_DH) walkable pack from explicit original inputs (copy of prepare_darker_jungle_portable.py).

Stages only the existing arrival renderer's consumed fields. Dark Halls gameplay (creatures, Rix, puzzles),
native boundary equivalence and full-game preparation are outside this command.
Existing output is refused. A later decoding failure may leave partial output.
"""
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path

def merge_props(result, prop_report, prop_root, review_root, attached=False):
    if attached:
        result['props'].extend(prop_report['props'])
        result.setdefault('attached_state_props', []).extend(prop_report.get('state_props', []))
        result.setdefault('attached_state_issues', []).extend(prop_report.get('state_issues', []))
    else:
        result['props'] = prop_report['props']
    sprite_by_image = {sprite['image']: sprite for sprite in prop_report.get('sprites', [])}
    for key, path in prop_report.get('materials', {}).items():
        result['materials'][key] = os.path.relpath(prop_root/path, review_root)
        result['alpha_cutout_materials'].append(key)
        sprite = sprite_by_image.get(path, {})
        if sprite.get('index'):
            result.setdefault('indexed_materials', {})[key] = os.path.relpath(prop_root/sprite['index'], review_root)
        if sprite.get('shadow'):
            result.setdefault('shadow_masks', {})[key] = os.path.relpath(prop_root/sprite['shadow'], review_root)
    for key, animation in prop_report.get('animations', {}).items():
        a = dict(animation)
        for field in ('frames', 'index_frames', 'shadow_frames'):
            if field in a:
                a[field] = [os.path.relpath(prop_root/p, review_root) for p in a[field]]
        result['animations'][key] = a
    if prop_report.get('initial_remap'):
        result['sprite_initial_remap'] = prop_report['initial_remap']
    result['summary']['sprite_shadow_compositing'] = 'pending; masks retained, color excludes index 1'
    prefix = 'attached_prop' if attached else 'prop'
    if attached:
        result.setdefault(prefix+'_issues', []).extend(prop_report.get('issues', []))
    else:
        result[prefix+'_issues'] = prop_report.get('issues', [])
    result['summary'][prefix+'s_rendered'] = len(prop_report['props'])
    result['summary'][prefix+'_issue_counts'] = prop_report.get('summary', {})
    if not attached:
        result['nonvisual_props'] = prop_report.get('nonvisual_props', [])
        result['summary']['props_nonvisual'] = len(result['nonvisual_props'])
    else:
        result.setdefault('attached_nonvisual_props', []).extend(prop_report.get('nonvisual_props', []))
        result.setdefault('attached_inactive_children', []).extend(prop_report.get('inactive_children', []))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--re-root', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    output = args.output_root.resolve()
    if output.exists():
        parser.error('--output-root must be fresh')
    for label, root in [('game', args.game_root), ('RE', args.re_root), ('tools', Path(__file__).parent)]:
        root = root.resolve()
        if not root.is_dir():
            parser.error(f'Missing {label} directory: {root}')
        if output == root or output in root.parents or root in output.parents:
            parser.error(f'Output overlaps {label} inputs')
    os.environ['LOL2_RE_ROOT'] = str(args.re_root.resolve())
    from lol2.map_geometry import export_geometry
    from lol2.map_ceiling_subdivisions import patch_geometry
    from lol2.map_source_walls import export_source_walls
    from lol2.map_materials import export_materials, load_inventory, area_by_id
    from lol2.map_surfaces import bind_surfaces
    from lol2.map_props import export_props
    from lol2.map_primitive_geometry import export_area as export_attached
    from export_map_movables import bind, export_movables
    from lol2.map_wall_admission import classify_area
    from lol2.map_boundary_fallbacks import export_area as boundaries
    from lol2.map_face_visibility import apply
    from lol2.map_lighting import bind as lights
    from lol2.map_sector_visibility import bind as sectors
    from lol2_rotation_table import rotation_table
    game = args.game_root.resolve()
    area = area_by_id(load_inventory(), 'L7_DH')
    archive = (game / area['source']['file']).read_bytes()
    if hashlib.sha256(archive).hexdigest() != area['source']['sha256']:
        parser.error('Unsupported L7_DH archive')
    rotation_table(game)
    bind(Path(__file__).parent, args.re_root)
    maps = output / 'tmp/dark_halls/maps'
    base = maps / 'L7_DH'
    export_geometry(game, 'L7_DH', base/'geometry')
    patch_geometry(base/'geometry', game)
    export_source_walls(game, 'L7_DH', base/'geometry', base/'geometry')
    export_materials(game, 'L7_DH', base/'materials')
    result = bind_surfaces(game, 'L7_DH', base/'geometry', base/'materials', base)
    props = export_props(game, 'L7_DH', base/'props', material_root=base/'materials')
    merge_props(result, props, base/'props', base)
    admission = classify_area(area, archive, maps)
    (base/'geometry/sector_admission.json').write_text(json.dumps(admission, indent=2)+'\n')
    for kind, folder, attached in [('movable','movables','attached_props'), ('static_assembly','static_assemblies','static_attached_props')]:
        report = export_movables(game, 'L7_DH', base/folder, material_root=maps, placement_kind=kind)
        for face in report['faces']:
            face['material'] = str(face['resource_id'])
        result['faces'].extend(report['faces'])
        used = {face['resource_id'] for face in report['faces']+report['state_faces']}
        for key, path in report['materials'].items():
            if int(key) in used:
                result['materials'][str(key)] = os.path.relpath(Path(report['materials_root'])/path, base)
        attached_report = export_attached(game, 'L7_DH', base/attached, placement_kind=kind)
        merge_props(result, attached_report, base/attached, base, attached=True)
    fallback = boundaries(base, base/'emulated_boundaries')
    missing = {face['material'] for face in fallback['faces']} - result['materials'].keys()
    if missing:
        raise ValueError(f'Unbound boundary materials: {sorted(missing)}')
    result['faces'].extend(fallback['faces'])
    entries = json.loads((base/'materials/materials.json').read_text())['materials']
    cutouts = set(result['alpha_cutout_materials'])
    for item in entries:
        if str(item['index']) in result['materials'] and (item.get('alpha_cutout') or item.get('has_alpha')):
            cutouts.add(str(item['index']))
    result['alpha_cutout_materials'] = sorted(cutouts)
    geometry = json.loads((base/'geometry/geometry.json').read_text())
    apply(result, geometry)
    lights(result, geometry, archive, (base/'materials/texture.bin').read_bytes(), base/'environment')
    sectors(result, geometry, archive)
    # Match the historical serialized review boundary: aliases between animation
    # dictionaries must not share mutations while paths are rewritten.
    result = json.loads(json.dumps(result))
    out = output/'assets/lol2/generated/dark_halls'
    out.mkdir(parents=True)
    copied = {}
    def stage(name):
        if name not in copied:
            source = (base/name).resolve()
            target = hashlib.sha256(source.read_bytes()).hexdigest()[:20]+'.png'
            shutil.copyfile(source, out/target)
            copied[name] = target
        return copied[name]
    result['materials'] = {key:stage(path) for key,path in result['materials'].items()}
    for animation in result['animations'].values():
        animation['frames'] = [stage(path) for path in animation['frames']]
        for field in ['index_frames','shadow_frames']:
            animation.pop(field, None)
    packed = {key:result[key] for key in ['source','faces','materials','animations','alpha_cutout_materials','props']}
    # L7 arrival selector 1 (region 47), the only L7 entry (L4 pocket region 3205 group 6292); body 32 above that floor.
    arrival = next(e for e in json.loads((base/'geometry/arrivals.json').read_text())['entries'] if e['selector'] == 1)
    floor = next(f for f in result['faces'] if f['kind'] == 'floor' and f.get('region') == arrival['region'])
    packed['start'] = [arrival['x'], max(p[1] for p in floor['points'])+32, -arrival['y']]
    packed['scope'] = 'Original terrain/initial scenery staged from all-map review. Source-sized walking slice; advanced sector lighting, prop shadows, alternate states, interactions, creatures and Dark Halls gameplay remain outside this renderer.'
    (out/'area.json').write_text(json.dumps(packed,separators=(',',':'))+'\n')
    print(f"Prepared {len(packed['faces'])} faces and {len(packed['props'])} scenery instances")


if __name__ == '__main__':
    main()
