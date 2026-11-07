#!/usr/bin/env python3
"""Prepare Cave lava bindings from fresh original geometry and material exports."""
import argparse
import hashlib
import json
import struct
import sys
import tempfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent / 'lol2'))
from map_geometry import export_geometry
from map_materials import export_materials
from map_surfaces import source_tables, resolve_resource

ARCHIVE = '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'
TEXTURE = '102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'


def require(value, message):
    if not value:
        raise ValueError(message)


def prepare(game, output):
    require(not output.exists(), 'Output must be a fresh directory')
    require(output != game and output not in game.parents and game not in output.parents, 'Output overlaps original game')
    require(hashlib.sha256((game / 'DAT/L1_DC.MIX').read_bytes()).hexdigest() == ARCHIVE, 'Unsupported Cave archive')
    with tempfile.TemporaryDirectory(prefix='cave-lava-') as work:
        work = Path(work)
        export_geometry(game, 'L1_DC', work / 'geometry')
        export_materials(game, 'L1_DC', work / 'materials')
        geometry = json.loads((work / 'geometry/geometry.json').read_text())
        faces = json.loads((work / 'geometry/faces.json').read_text())['faces']
        texture = (work / 'materials/texture.bin').read_bytes()
        require(hashlib.sha256(texture).hexdigest() == TEXTURE, 'Cave texture differs')
        _, _, presets = source_tables(game, 'L1_DC')
        resources = {p['index']: resolve_resource(p['resource'], texture)[0] for p in presets}
        require(resources[16] == 135 and presets[16]['resource'] == -1, 'Lava material indirection differs')
        regions = []
        for face in faces:
            if face['kind'] != 'floor':
                continue
            region = geometry['regions'][face['region']]
            selector = struct.unpack('<22H', bytes.fromhex(region['raw_hex']))[16] & 255
            if resources.get(selector) != 135:
                continue
            points = face['points']
            require(len({p[1] for p in points}) == 1, 'Expected flat lava floor')
            regions.append(dict(region=face['region'], floor=float(points[0][1]),
                                polygon=[[p[0], p[2]] for p in points]))
        require(len(regions) == len({r['region'] for r in regions}) == 86, 'Lava region count differs')
        result = dict(material=135, source=geometry['source'], regions=regions,
                      scope='Recovered material135 floor ownership; user confirms lava is lethal. Immediate grounded-contact death is modern policy; native damage cadence/immunities not verified. Seven other unresolved floor materials are excluded.')
        target = output / 'assets/lol2/generated/cave_lava/regions.json'
        target.parent.mkdir(parents=True)
        target.write_text(json.dumps(result, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        prepare(args.game.resolve(), args.output_root.resolve())
    except (ValueError, OSError, KeyError, IndexError, struct.error) as error:
        parser.error(str(error))
    print('PASS 86 original Cave lava floor bindings')


if __name__ == '__main__':
    main()
