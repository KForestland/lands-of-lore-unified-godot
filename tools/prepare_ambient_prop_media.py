#!/usr/bin/env python3
"""Prepare Cave side-chamber and Jungle beehive images from original files."""
import argparse
import hashlib
import json
import shutil
import tempfile
from pathlib import Path
from lol2 import map_materials, map_props
from lol2_source_format import parse_mix, u32
from prepare_museum_key_locks import definitions, icon

CONTRACTS = {'cave_side_chamber': '16a6582bc164b6a7cb0b7fd6518a519c06e81b343cf00e332afc0ecb747eed27', 'jungle_beehives': '5247fc1147e18ceaccdaf6d24ff081922f8659f18c3e73dc9ba0c19547ed7d55'}
ORIGINALS = {
    'DAT/L1_DC.MIX': '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345',
    'DAT/L4_HJ.MIX': '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f',
    'GLOBAL.MIX': '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd',
    'LOCAL.MIX': 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278',
}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def prepare(game, contracts, output):
    require(not output.exists(), 'Output must be a fresh directory')
    for path in (game, contracts):
        require(output != path and output not in path.parents and path not in output.parents,
                'Output overlaps input')
    for name, wanted in ORIGINALS.items():
        require(digest((game / name).read_bytes()) == wanted, 'Unsupported original: ' + name)
    sources = {}
    for name, wanted in CONTRACTS.items():
        raw = (contracts / (name + '_source.json')).read_bytes()
        require(digest(raw) == wanted, 'Unsupported contract: ' + name)
        sources[name] = json.loads(raw)
    with tempfile.TemporaryDirectory(prefix='ambient-props-') as scratch:
        scratch = Path(scratch)
        staged = scratch / 'staged'
        for area, pack in [('L1_DC', 'cave_side_chamber'), ('L4_HJ', 'jungle_beehives')]:
            root = scratch / area
            map_materials.export_materials(game, area, root / 'materials')
            map_props.export_props(game, area, root / 'props', root / 'materials')
            report = json.loads((root / 'props/props.json').read_text())
            props = {p['record']: p for p in report['props']}
            contract = sources[pack]
            require(contract['source']['sha256'] == ORIGINALS['DAT/' + area + '.MIX'], 'Contract archive')
            out = staged / pack
            out.mkdir(parents=True)
            if pack == 'cave_side_chamber':
                for number, wanted in contract['props'].items():
                    prop = props[int(number)]
                    require(prop['animated'] and all(prop[k] == wanted[k] for k in
                            ['position', 'region', 'template', 'material', 'left', 'right', 'bottom', 'top']),
                            'Cave prop binding differs: ' + number)
                    for index, name in enumerate(wanted['frames']):
                        require(name == '%s_%d_index.png' % (prop['material'], index), 'Frame name differs')
                        image = root / 'props/sprites' / ('%s_frame_%d_index.png' % (prop['material'], index))
                        shutil.copyfile(image, out / name)
                    require(not (root / 'props/sprites' / ('%s_frame_%d_index.png' %
                            (prop['material'], len(wanted['frames'])))).exists(), 'Extra Cave frame')
            else:
                for number, wanted in contract['hives'].items():
                    prop = props[int(number)]
                    require(prop['template'] == 56 and prop['selector'] == 0 and
                            all(prop[k] == wanted[k] for k in ['position', 'region']), 'Beehive binding differs')
                archive = (game / 'DAT/L4_HJ.MIX').read_bytes()
                entry = next(e for e in parse_mix(archive) if e['key'] == 3710142494)
                templates = map_props.load_templates(archive[entry['offset']:entry['offset'] + entry['size']])['templates']
                texture = (root / 'materials/texture.bin').read_bytes()
                sections = map_props.mm.sections(texture)
                palette = map_props.mm.rgb_palette(texture[u32(texture, 4):][:768], 6)
                work = root / 'selectors'
                (work / 'sprites').mkdir(parents=True)
                selectors = templates[56]['selectors']
                require(len(selectors) == len(contract['selectors']), 'Beehive selector count')
                for selector, wanted in zip(selectors, contract['selectors']):
                    require(len(selector['frames']) == 1, 'Expected one beehive frame')
                    frame = selector['frames'][0]
                    require(selector['selector'] == wanted['selector'] and
                            all(frame[k] == wanted[k] for k in ['descriptor', 'left', 'right', 'bottom']) and
                            selector['state_height'] - frame['top_trim'] == wanted['top'], 'Beehive selector differs')
                    image = map_props.build_image(frame['descriptor'], texture, sections, palette,
                                                  work / 'sprites', work, {})
                    decoded = work / image.get('frames', [image['image']])[0]
                    require(digest(decoded.read_bytes()) == wanted['sha256'], 'Beehive image hash differs')
                    shutil.copyfile(decoded, out / wanted['image'])
                blob, base, count, names = definitions(game=game)
                matches = [i for i in range(count) if u32(blob, base + i * 91 + 24) == contract['wax']['identity']]
                require(len(matches) == 1 and names[matches[0]] == contract['wax']['name'], 'Wax identity differs')
                icon(matches[0], out / contract['wax_icon'], game=game)
        target = output / 'assets/lol2/generated'
        target.mkdir(parents=True)
        for pack in sources:
            shutil.copytree(staged / pack, target / pack)
    return {'cave_side_chamber': 30, 'jungle_beehives': 4}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game', 'contracts', 'output-root']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        result = prepare(args.game.resolve(), args.contracts.resolve(), args.output_root.resolve())
    except (ValueError, OSError, KeyError) as error:
        parser.error(str(error))
    print(json.dumps(result))


if __name__ == '__main__':
    main()
