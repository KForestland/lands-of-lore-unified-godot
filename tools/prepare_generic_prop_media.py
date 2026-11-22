#!/usr/bin/env python3
"""Original charger/orb and class-C prop selectors, using the existing map_props producer unchanged.

Run from the project tools directory after installation. Output must be fresh;
the game input is read only. Generated images stay outside version control.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import tempfile

from lol2 import map_materials as materials, map_props as props

OBJECTS = {'L10_DC': {242: 61, 247: 61},
           'L9_DR': {1087: 12, 1088: 12, 1089: 12, 1090: 12, 1094: 64},
           'L20_BB': {index:12 for index in [144,145,146,153,154,155]}}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def export_area(game, area, output):
    source = materials.area_by_id(materials.load_inventory(), area)['source']
    mix = (game / source['file']).read_bytes()
    if digest(mix) != source['sha256']:
        raise ValueError(f'{area}: unsupported or changed archive')
    entries = materials.identify_entries(mix, materials.parse_mix(mix), source['geometry_key'])
    entry = entries['metadata_entry']
    meta = mix[entry['offset']:entry['offset'] + entry['size']]
    templates = [t for t in props.load_templates(meta)['templates']
                 if t['index'] in OBJECTS[area].values()]
    blob, _ = materials.decode_lzo_container(mix, entries['texture_entry'])
    sections = materials.sections(blob)
    palette = struct.unpack_from('<I', blob, 4)[0]
    rgb = materials.rgb_palette(blob[palette:palette + 768], 6)
    output.mkdir()
    visuals, issues, extra, deferred, images, animations = props.resolve_templates(
        templates, blob, sections, rgb, output / 'sprites', output, {})
    if issues or extra or deferred:
        raise ValueError(f'{area}: pilot selector did not resolve: {issues}, {extra}, {deferred}')
    # Bind only only the published placements. Decode/render bounds are the
    # producer's; this adapter does not reinterpret native sprite formats.
    report = {'version': 1, 'area': area, 'source': source,
              'objects': {str(k): v for k, v in OBJECTS[area].items()},
              'selectors': {f'{t}:{s}': row for (t, s), row in visuals.items()},
              'materials': images, 'animations': animations,
              'timing': '10 fps modern presentation; native timing unverified'}
    write_json(output / 'selectors.json', report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    game, output = args.game.resolve(), args.output.resolve()
    if output.exists() or game == output or game in output.parents or output in game.parents:
        parser.error('Output must be fresh and separate from the original game')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.generic-props-', dir=output.parent) as tmp:
        stage = Path(tmp)
        for area in OBJECTS:
            export_area(game, area, stage / area)
        files = {p.relative_to(stage).as_posix(): {'sha256': digest(p.read_bytes()), 'bytes': p.stat().st_size}
                 for p in sorted(stage.rglob('*')) if p.is_file()}
        write_json(stage / 'manifest.json', {'version': 1, 'producer': Path(__file__).name,
                   'scope': 'L10 chargers, L9 orbs, L20 class-C template12 selectors', 'files': files})
        shutil.copytree(stage, output)
    print(f'PASS original prop selectors: {sum(len(rows) for rows in OBJECTS.values())} objects, {len(files)} pinned outputs')


if __name__ == '__main__':
    main()
