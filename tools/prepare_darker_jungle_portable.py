#!/usr/bin/env python3
"""Rebuild the darker-Jungle arrival or L9 dragon map from explicit original inputs.

L8 includes decoded arrivals for connected travel; --area L9_DR stages the dragon map. Act 2 gameplay,
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
    parser.add_argument('--area', choices=['L8_SJ', 'L9_DR'], default='L8_SJ')
    args = parser.parse_args()
    area_id = args.area
    pack_name = 'darker_jungle' if area_id == 'L8_SJ' else 'dragon_level'
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
    area = area_by_id(load_inventory(), area_id)
    archive = (game / area['source']['file']).read_bytes()
    if hashlib.sha256(archive).hexdigest() != area['source']['sha256']:
        parser.error(f'Unsupported {area_id} archive')
    rotation_table(game)
    bind(Path(__file__).parent, args.re_root)
    maps = output / ('tmp/'+pack_name+'/maps')
    base = maps / area_id
    export_geometry(game, area_id, base/'geometry')
    patch_geometry(base/'geometry', game)
    export_source_walls(game, area_id, base/'geometry', base/'geometry')
    export_materials(game, area_id, base/'materials')
    result = bind_surfaces(game, area_id, base/'geometry', base/'materials', base)
    if area_id != 'L8_SJ':
        from lol2.map_environment import export_from_game
        sky_out = output/'assets/lol2/generated/dragon_sky'
        sky_report = export_from_game(game, area_id, base/'materials', sky_out)
        if sky_report.get('panorama'):
            (sky_out/'environment.json').write_text(json.dumps(dict(area=area_id, panorama=sky_report['panorama']), indent=2)+'\n')
    props = export_props(game, area_id, base/'props', material_root=base/'materials')
    merge_props(result, props, base/'props', base)
    admission = classify_area(area, archive, maps)
    (base/'geometry/sector_admission.json').write_text(json.dumps(admission, indent=2)+'\n')
    for kind, folder, attached in [('movable','movables','attached_props'), ('static_assembly','static_assemblies','static_attached_props')]:
        report = export_movables(game, area_id, base/folder, material_root=maps, placement_kind=kind)
        for face in report['faces']:
            face['material'] = str(face['resource_id'])
        result['faces'].extend(report['faces'])
        used = {face['resource_id'] for face in report['faces']+report['state_faces']}
        for key, path in report['materials'].items():
            if int(key) in used:
                result['materials'][str(key)] = os.path.relpath(Path(report['materials_root'])/path, base)
        attached_report = export_attached(game, area_id, base/attached, placement_kind=kind)
        merge_props(result, attached_report, base/attached, base, attached=True)
    # Floors whose source selector is 255 have no surface material: bind_surfaces omits them (44 L8 regions, 31 of them bit0,
    # 43 adjoining a passable region), so the walking scene had no collision there. The Act 1 Jungle keeps such floors as
    # material-less faces: collision only (draw_floorless false) and, with fill_untextured_edges, the nearest textured floor's
    # material (DEVIATIONS 2026-10-25). Appended at the end so every earlier face index stays. L8 only for now (the L9 pack
    # stays as the astra-maps lane qualified it; extending this to L9 is a follow-up).
    floorless = []
    if area_id == 'L8_SJ':
        floor_regions = {face['region'] for face in result['faces'] if face['kind'] == 'floor'}
        geometry_faces = json.loads((base/'geometry/faces.json').read_text())['faces']
        floorless = [dict(kind='floor', region=face['region'], points=face['points'], floorless=True)
                     for face in geometry_faces if face['kind'] == 'floor' and face['region'] not in floor_regions]
    fallback = boundaries(base, base/'emulated_boundaries') if area_id == 'L8_SJ' else {'faces': []}
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
    # After the visibility, lighting and sector passes (they key on a material): the floorless floors carry none.
    result['faces'].extend(floorless)
    out = output/'assets/lol2/generated'/pack_name
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
    packed['start'] = [-4577,32,1168] if area_id == 'L8_SJ' else result['start']
    packed['arrivals'] = result['arrivals']
    if area_id != 'L8_SJ':
        for face in packed['faces']:
            if face['kind'] == 'source_wall':
                face['kind'] = 'wall'
                face['source_wall'] = True
    packed['scope'] = 'Original terrain/initial scenery staged from all-map review. Source-sized walking arrival; advanced sector lighting, source sky, prop shadows, alternate states, interactions and Act2 gameplay remain outside this arrival renderer.'
    if area_id != 'L8_SJ':
        packed['scope'] = 'Original L9 initial map. Arrival selector0 is a preview choice, campaign entry UNKNOWN. Walls drawn only. Missing-neighbor walls omitted pending witness. No progression hosting.'
    (out/'area.json').write_text(json.dumps(packed,separators=(',',':'))+'\n')
    print(f"Prepared {len(packed['faces'])} faces ({len(floorless)} floorless collision floors) and {len(packed['props'])} scenery instances")


if __name__ == '__main__':
    main()
