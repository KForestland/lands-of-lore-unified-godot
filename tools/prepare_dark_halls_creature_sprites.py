#!/usr/bin/env python3
"""Stage L7_DH SHADE (0), Rat (1) and RIX (2) creature sprites with the Museum creature-sprite recipe.

Same decode path as prepare_museum_creature_sprites.py (state views, action rows, frame events, indexed frames).
The texture container is the one map_materials writes for L7_DH (prepare_dark_halls_portable.py keeps it under
OUTPUT/tmp/dark_halls/maps/L7_DH/materials/texture.bin). Empty sprite records (zero-length payloads in L7_DH) are
listed as unsupported instead of aborting.
Usage: prepare_dark_halls_creature_sprites.py --game GAME --texture TEXTURE.bin --output FRESH_DIR
"""
import argparse, struct
from pathlib import Path
import prepare_museum_creature_sprites as Museum

_decode = Museum.decode_rows
def _guarded(payload, **kw):
    if len(payload) < 8: raise ValueError('empty sprite record')
    try: return _decode(payload, **kw)
    except struct.error as error: raise ValueError(str(error))
Museum.decode_rows = _guarded


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--texture', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): p.error('Use a fresh output directory')
    Museum.stage('DAT/L7_DH.MIX', a.texture.read_bytes(), [0, 1, 2], a.output, game=a.game)


if __name__ == '__main__':
    main()
