#!/usr/bin/env python3
"""Prepare existing Jungle harvest images from explicit originals and fresh texture data."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from lol2 import map_props as props
from lol2_source_format import parse_mix, u32
from prepare_museum_key_locks import icon

CONTRACT_SHA = 'e0c38b17535544d065975baad0d3be1f62c7747259af563305e6cd47c82aa280'
ARCHIVE_SHA = '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'
TEXTURE_SHA = '98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def prepare(game, texture, source, output):
    for label, path in [('game', game), ('texture', texture), ('source', source)]:
        require(path.exists(), f'Missing {label}: {path}')
        require(output != path and output not in path.parents and path not in output.parents,
                f'Output overlaps {label}')
    require(not output.exists(), 'Output must be a fresh directory')
    raw = source.read_bytes()
    require(digest(raw) == CONTRACT_SHA, 'Unsupported harvest source contract')
    contract = json.loads(raw)
    arc = (game / 'DAT/L4_HJ.MIX').read_bytes()
    require(digest(arc) == ARCHIVE_SHA, 'Unsupported Jungle archive')
    entries = [e for e in parse_mix(arc) if e['key'] == 3710142494]
    require(len(entries) == 1, 'Expected one Jungle metadata entry')
    meta = entries[0]
    templates = props.load_templates(arc[meta['offset']:meta['offset'] + meta['size']])['templates']
    tex = texture.read_bytes()
    require(digest(tex) == TEXTURE_SHA, 'Unsupported decoded Jungle texture')
    selections = []
    for stem, template in [('plant', 104), ('tree', 105), ('single', 52)]:
        selectors = templates[template]['selectors']
        require(len(selectors) == len(contract['art'][stem]), f'{stem}: selector count')
        for selector, want in zip(selectors, contract['art'][stem]):
            require(len(selector['frames']) == 1, f'{stem}: expected one frame')
            frame = selector['frames'][0]
            require(selector['selector'] == want['selector'] and
                    all(frame[k] == want[k] for k in ('descriptor', 'left', 'right')),
                    f'{stem}: original selector differs from contract')
            selections.append(want)
    out = output / 'assets/lol2/generated/jungle_harvest'
    scratch = output / 'tmp/jungle_harvest'
    out.mkdir(parents=True)
    (scratch / 'sprites').mkdir(parents=True)
    sections = props.mm.sections(tex)
    palette = props.mm.rgb_palette(tex[u32(tex, 4):][:768], 6)
    for want in selections:
        image = props.build_image(want['descriptor'], tex, sections, palette,
                                  scratch / 'sprites', scratch, {})
        decoded = scratch / image.get('frames', [image['image']])[0]
        require(digest(decoded.read_bytes()) == want['sha256'], 'Decoded selector hash differs')
        shutil.copyfile(decoded, out / want['image'])
    for name in ('aloe', 'sap'):
        icon(contract[name]['definition'], out / (name + '.png'), game=game)
    return dict(runtime_files=10, archive_sha256=ARCHIVE_SHA, texture_sha256=TEXTURE_SHA)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('game', 'texture', 'source', 'output-root'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        result = prepare(args.game.resolve(), args.texture.resolve(), args.source.resolve(),
                         args.output_root.resolve())
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
