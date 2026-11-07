#!/usr/bin/env python3
"""Rebuild the existing Cave chain preview from the pinned original archive."""
import argparse
import json
import struct
import tempfile
from pathlib import Path
from PIL import Image
from lol2 import map_props
from lol2_source_format import parse_mix, u32
from lol2_creature_sprite_format import require
from build_game_atlas import section
from prepare_cave_props_media import selected_height


def prepare(game, output):
    require(not output.exists(), 'Output must be fresh')
    require(output != game and output not in game.parents and game not in output.parents,
            'Output overlaps input')
    # The shared exporter validates the archive hash and independently decodes its texture.
    with tempfile.TemporaryDirectory(prefix='lol2-chain-') as temporary:
        props = Path(temporary) / 'props'
        map_props.export_props(game, 'L1_DC', props)
        mix = (game / 'DAT/L1_DC.MIX').read_bytes()
        entries = {e['key']: e for e in parse_mix(mix)}
        geo, meta = [mix[entries[k]['offset']:entries[k]['offset'] + entries[k]['size']]
                     for k in (2971673856, 2971019266)]
        record = 544
        offset = u32(geo, 0x14) + record * 37
        placement = geo[offset:offset + 37]
        template_id = struct.unpack_from('<H', placement, 32)[0]
        region = struct.unpack_from('<H', placement, 10)[0]
        require((template_id, region) == (77, 799), 'Unexpected chain placement')
        template = map_props.load_templates(meta)['templates'][template_id]
        regions = list(struct.iter_unpack('<22H', section(geo, 12, 0x58, 44)[2]))
        floor, ceiling = struct.unpack('<hh', struct.pack('<HH', *regions[region][10:12]))
        states = []
        for selector in template['selectors']:
            frame = selector['frames'][0]
            height = selected_height(template['flags'], True, floor, ceiling, selector['state_height'])
            # Compatibility: this preview historically uses full region height, without top trim.
            states.append(dict(selector=selector['selector'], resource=frame['descriptor'],
                               left=frame['left'], right=frame['right'], bottom=frame['bottom'],
                               top=height, flags=frame['frame_flags']))
        require([s['resource'] for s in states] == [87, 89, 88] and height == 60,
                'Unexpected chain states')
        x, y, z = (struct.unpack_from('<h', placement, o)[0] for o in (0, 2, 6))
        manifest = dict(record=record, position=[x / 64, z / 64, -y / 64],
                        placement_hex=placement.hex(), states=states,
                        scope='Source position and state width/trims with verified region799 height60. Fixed-Y billboard, normalized UV and palette transparency remain preview choices.',
                        region=region, height_proof=dict(record=record, template=template_id,
                        region=region, flags=template['flags'], height=height))
        images = []
        for resource, count in ((87, 1), (88, 1), (89, 27)):
            for frame in range(count):
                for indexed in (False, True):
                    suffix = '_index' if indexed else ''
                    candidates = [props / 'sprites' / f'prop_{resource}_frame_{frame}{suffix}.png',
                                  props / 'sprites' / f'prop_{resource}{suffix}.png']
                    source = next((p for p in candidates if p.is_file()), None)
                    require(source is not None, 'Missing chain frame')
                    with Image.open(source) as image:
                        require(image.size == (245, 439) and image.mode == ('L' if indexed else 'RGBA'),
                                'Unexpected chain image format')
                        images.append((f'{"indices_" if indexed else ""}resource_{resource}_frame_{frame}.png', image.copy()))
        destination = output / 'assets/lol2/chain'
        destination.mkdir(parents=True)
        for name, image in images:
            image.save(destination / name, format='PNG')
        (destination / 'chain.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Prepared 59 Cave chain files')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        prepare(args.game.resolve(), args.output_root.resolve())
    except (ValueError, OSError, AssertionError, KeyError, IndexError, struct.error) as error:
        parser.error(str(error) or 'Source validation failed')


if __name__ == '__main__':
    main()
