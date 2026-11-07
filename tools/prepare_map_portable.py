#!/usr/bin/env python3
"""Rebuild one Act 2/3 map pack from explicit original inputs: the L8 darker-jungle recipe (prepare_darker_jungle_portable.py)
with an area argument. Output assets/lol2/generated/maps/AREA/area.json plus the staged images: floors (incl. the selector-255
floorless collision floors), ceilings, the original's rendered source walls, static-assembly and movable faces, emulated
boundary quads, batched prop rows, and the test start = one native arrival record (MAPS table, witnessed below).
Existing output is refused. A later decoding failure may leave partial output. Scripts, items, actors and lighting are not here.
"""
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path
from prepare_darker_jungle_portable import merge_props

MAPS = {
    'L20_BB': dict(start_selector=0, start_witness='Native arrival selector0 chosen for isolated map preview. Original entry coordinates and region are verified from the archive. Campaign entry and adjacent-label binding UNKNOWN; selection is an adapter.'),
    'L17_HC': dict(start_selector=0, start_witness='Native arrival selector0 chosen for isolated map preview. Original entry coordinates and region are verified from the archive. Campaign entry and adjacent-label binding UNKNOWN; selection is an adapter.'),
    'L14_HT': dict(start_selector=0, start_witness='Native arrival selector0 chosen for isolated map preview. Original entry coordinates and region are verified from the archive. Campaign entry and adjacent-label binding UNKNOWN; selection is an adapter.'),
    'L12_CM': dict(start_selector=0, start_witness='Native arrival selector0 chosen for isolated map preview. Original entry coordinates and region are verified from the archive. Campaign entry and adjacent-label binding UNKNOWN; selection is an adapter.'),
    'L10_DC': dict(start_selector=2, start_witness=(
        "Arrival selector 2 (-542, 856, heading 24758, region 65) sits beside region 42, the owner of the level change the export "
        "labels 'Teleport to Dracoid Ruins'; the owner's longplay enters this level through a teleport portal (137:10) and stands "
        "in the dungeon at 137:40. Selector 1 (region 5) sits beside region 0, the 'Savage Jungle' exit; selector 0 (region 3782) "
        "has no adjacent level change. The level-change destination byte stays undecoded (G93), so this is an adapter.")),
    'L13_RC': dict(start_selector=0, start_witness=(
        "Arrival selectors 0 (-3344, -6564, heading 28089, region 488) and 1 (-3260, -6631, heading 1, region 487) both sit beside "
        "region 489, the owner of this level's only level change (G93: one `020100001c` command); selectors 2 (region 636, floor -1080) "
        "and 3 (region 323) are elsewhere. Selector 0 is the first of the pair. The owner's longplay shows this level (the "
        "'Remaining Ruloi 19/19' counter; 20 RULOI actor rows) from about 202:30. The destination byte stays undecoded, so this is an adapter.")),
        'L16_CA': dict(start_selector=1, start_witness=(
        "Arrival selector 1 (-3860, 1341, heading 1, region 137): the arrival of the level change L14_HT stream 1 group 9210 `020100001c30` "
        "(byte 5 0x30 = level 16, selector 1; file 11721792), owned by prop 170's kind-6 record (file 11739888, caller byte 0x14, predicate 50 = "
        "local 22 == 1) in the Huline temple. Owner 2026-10-31: the L16 preview starts where the player arrives from the Huline temple after its "
        "puzzles and the dream orb. The other arrivals: selector 3 from L17_HC group 1644 (`020100001c70`), selector 2 from L17_HC group 3896 "
        "(`020100001c50`), selector 0 from no framed level change. Until 2026-10-31 the preview used selector 3 (beside the L17 exit) as an adapter.")),
'L19_BC': dict(start_selector=1, start_witness=(
        "Arrival selector 1 (84, -305, heading 49152, region 25) sits 69 units from region 22, the owner of the level's unpredicated level change "
        "(G93: `020100001c51`); selector 2 (region 2365) sits 106 units from region 2369, which owns the two predicated level changes (204/205); "
        "selectors 0 (region 1691) and 3 (region 1715) are beside neither. The L17_HC and L20_BB exports' exit labels name this level "
        "'Belial's Chamber'. The destination byte stays undecoded, so this is an adapter.")),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True)
    parser.add_argument('--re-root', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    parser.add_argument('--area', choices=sorted(MAPS), required=True)
    parser.add_argument('--start-selector', type=int, default=None, help='arrival selector for the test start (default: the MAPS table)')
    args = parser.parse_args()
    area_id = args.area
    spec = MAPS[area_id]
    selector = spec['start_selector'] if args.start_selector is None else args.start_selector
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
    maps = output / 'tmp/maps' / area_id / 'maps'
    base = maps / area_id
    export_geometry(game, area_id, base/'geometry')
    patch_geometry(base/'geometry', game)
    export_source_walls(game, area_id, base/'geometry', base/'geometry')
    export_materials(game, area_id, base/'materials')
    result = bind_surfaces(game, area_id, base/'geometry', base/'materials', base)
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
    # Floors whose source selector is 255 have no surface material: bind_surfaces omits them, so the walking scene would have
    # no collision there. The Act 1 Jungle keeps such floors as material-less faces: collision only (draw_floorless false) and,
    # with fill_untextured_edges, the nearest textured floor's material (DEVIATIONS 2026-10-25). Appended at the end so every
    # earlier face index stays (the L8 rule, prepare_darker_jungle_portable.py).
    floor_regions = {face['region'] for face in result['faces'] if face['kind'] == 'floor'}
    geometry_faces = json.loads((base/'geometry/faces.json').read_text())['faces']
    floorless = [dict(kind='floor', region=face['region'], points=face['points'], floorless=True)
                 for face in geometry_faces if face['kind'] == 'floor' and face['region'] not in floor_regions]
    fallback = boundaries(base, base/'emulated_boundaries') if area_id not in ('L12_CM', 'L14_HT', 'L17_HC', 'L20_BB') else {'faces': []}
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
    out = output/'assets/lol2/generated/maps'/area_id
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
    arrivals = json.loads((base/'geometry/arrivals.json').read_text())
    entry = next(e for e in arrivals['entries'] if e['selector'] == selector)
    region = geometry['regions'][entry['region']]
    # The L8 pack starts 32 above its arrival region's floor ([-4577, 32, 1168] on floor 0); the same height here.
    packed['start'] = [entry['x'], min(region['floor_corners']) + 32, -entry['y']]
    packed['start_heading_units'] = entry['heading_units']
    packed['start_selector'] = selector
    packed['start_witness'] = spec['start_witness']
    packed['arrivals'] = [dict(selector=e['selector'], x=e['x'], y=e['y'], heading_units=e['heading_units'], region=e['region']) for e in arrivals['entries']]
    packed['adjacent_labels'] = arrivals.get('adjacent_labels', [])
    packed['area'] = area_id
    packed['scope'] = 'Original terrain/initial scenery staged from the all-map producers (the L8 darker-jungle recipe with an area argument). Source-sized walking map from one native arrival; advanced sector lighting, prop shadows, alternate states, scripts, items, actors and gameplay remain outside this pack.'
    if area_id in ('L12_CM', 'L14_HT', 'L17_HC', 'L20_BB'):
        for face in packed['faces']:
            if face['kind'] == 'source_wall':
                face['kind'] = 'wall'
                face['source_wall'] = True
    (out/'area.json').write_text(json.dumps(packed,separators=(',',':'))+'\n')
    print(f"Prepared {area_id}: {len(packed['faces'])} faces ({len(floorless)} floorless collision floors), {len(packed['props'])} scenery instances, start selector {selector} at {packed['start']} heading {entry['heading_units']}")


if __name__ == '__main__':
    main()
