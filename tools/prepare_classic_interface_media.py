#!/usr/bin/env python3
"""Stage the original inventory panel pieces and ring animations from intrface.shp.

  python3 tools/prepare_classic_interface_media.py --game GAME --output-root FRESH

Writes FRESH/assets/lol2/generated/classic_interface/shape_NNN.png and manifest.json for the shapes listed in ROLES.
Same originals and pins as tools/prepare_classic_hud.py (GLOBAL.MIX intrface.shp key 606080735, LOCAL.MIX base
palette key 1915865337); same published shape decoder (prepare_museum_interface.shape) and PNG convention (palette
index 0 transparent). Roles are identified visually against the original longplay (inventory open at 28m30s, ring
splash at 22m30s); they are presentation roles, not native code bindings.
The output root must not exist and must not overlap the game directory. Every shape is decoded and checked before
anything is written.
"""
import argparse
import hashlib
import json
import sys
import tempfile
import shutil
from pathlib import Path

SHP_KEY, PAL_KEY = 606080735, 1915865337
SHP_SHA = '1c03f2a0f739368c66078103d43131ea0fde26bfffdd34186b21611dde3fd50e'
PAL_SHA = '520c6fe31ccb9d5e1044b958e082df7919d63b46008dee9965d1b1e956a17729'
# shape index -> (role, expected width, expected height)
ROLES = {
    78: ('inventory_cell', 24, 24),
    86: ('equipment_slot', 24, 24),
    87: ('equipment_ghost_0', 24, 24), 88: ('equipment_ghost_1', 24, 24), 89: ('equipment_ghost_2', 24, 24),
    90: ('equipment_ghost_3', 24, 24), 91: ('equipment_ghost_4', 24, 24), 92: ('equipment_ghost_5', 24, 24),
    93: ('tab_red', 11, 21), 94: ('tab_red_pressed', 11, 21), 95: ('tab_green', 15, 11), 96: ('tab_green_pressed', 15, 11),
    111: ('stat_icon_defense', 10, 8), 112: ('stat_icon_strength', 10, 8), 113: ('stat_icon_melee', 10, 8),
    114: ('stat_icon_ranged', 10, 8), 115: ('stat_icon_armed', 10, 8), 116: ('stat_icon_magic', 10, 8),
    122: ('stat_bar', 39, 4), 57: ('health_fill', 39, 4), 59: ('mana_fill', 25, 4),
    132: ('magic_ring_cast_0', 21, 21), 133: ('magic_ring_cast_1', 21, 21), 134: ('magic_ring_cast_2', 21, 21),
    135: ('magic_ring_cast_3', 21, 21), 136: ('magic_ring_cast_4', 21, 21), 137: ('magic_ring_cast_5', 21, 21),
    138: ('attack_ring_strike_0', 21, 21), 139: ('attack_ring_strike_1', 21, 21), 140: ('attack_ring_strike_2', 21, 21),
    141: ('attack_ring_strike_3', 21, 21), 142: ('attack_ring_strike_4', 21, 21), 143: ('attack_ring_strike_5', 21, 21),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game', type=Path, required=True, help='directory containing GLOBAL.MIX and LOCAL.MIX')
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    game, output = args.game.resolve(), args.output_root.resolve()
    if output.exists():
        parser.error('--output-root must not exist')
    if output == game or game in output.parents or output in game.parents:
        parser.error('--output-root overlaps --game')
    try:
        from PIL import Image
        from lol2_source_format import parse_mix
        from prepare_museum_interface import shape
    except ImportError as error:
        parser.error(f'missing dependency: {error}')

    def blob(archive, key):
        path = game / archive
        if not path.is_file():
            parser.error(f'missing original {path}')
        data = path.read_bytes()
        entry = next((e for e in parse_mix(data) if e['key'] == key), None)
        if entry is None:
            parser.error(f'{path} has no MIX key {key}')
        return data[entry['offset']:entry['offset'] + entry['size']]

    shp, pal = blob('GLOBAL.MIX', SHP_KEY), blob('LOCAL.MIX', PAL_KEY)
    if sha(shp) != SHP_SHA:
        parser.error('intrface.shp differs from the pinned original')
    if sha(pal) != PAL_SHA:
        parser.error('base palette differs from the pinned original')
    palette = bytes(round(v * 255 / 63) for v in pal)
    decoded, shapes = [], {}
    for index, (role, width, height) in sorted(ROLES.items()):
        w, h, pixels = shape(shp, index)
        if (w, h) != (width, height):
            parser.error(f'shape {index} is {w}x{h}, expected {width}x{height}')
        name = f'shape_{index:03d}.png'
        decoded.append((name, w, h, pixels))
        shapes[str(index)] = dict(role=role, file=name, width=w, height=h, indices_sha256=sha(pixels))
    manifest = dict(version=1, source=dict(archive='GLOBAL.MIX', key=SHP_KEY, sha256=SHP_SHA, palette_sha256=PAL_SHA),
                    scale=2, shapes=shapes,
                    reference='original longplay: inventory open 28m30s (4x5 red cells, stat rows shield/fist/sword/bow, '
                              '2x3 grey equipment slots); ring splash 22m30s',
                    scope='Original interface shapes. Roles are visual identifications against the reference, not native '
                          'code bindings; layout and timing of their use are presentation adapters.')
    with tempfile.TemporaryDirectory(prefix='classic-interface-') as tmp:
        stage = Path(tmp) / 'assets/lol2/generated/classic_interface'
        stage.mkdir(parents=True)
        for name, w, h, pixels in decoded:
            image = Image.frombytes('P', (w, h), pixels)
            image.putpalette(palette)
            image.save(stage / name, transparency=0)
            if Image.open(stage / name).tobytes() != pixels:
                parser.error(f'{name}: PNG index roundtrip failed')
        (stage / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
        output.mkdir(parents=True)
        shutil.copytree(Path(tmp) / 'assets', output / 'assets')
    print(f'Staged {len(decoded)} original interface shapes under {output}/assets/lol2/generated/classic_interface')


if __name__ == '__main__':
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    main()
