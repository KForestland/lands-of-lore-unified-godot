#!/usr/bin/env python3
"""Prepare the original Dampen charm icon from explicit game files."""
import argparse
import hashlib
from pathlib import Path
import tempfile
from lol2_source_format import u32
from prepare_museum_key_locks import definitions, icon

ORIGINALS = {
    'GLOBAL.MIX': '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd',
    'LOCAL.MIX': 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278',
}


def prepare(game, output):
    if output.exists():
        raise ValueError('Output must be fresh')
    if output == game or output in game.parents or game in output.parents:
        raise ValueError('Output overlaps original game')
    for name, expected in ORIGINALS.items():
        if hashlib.sha256((game/name).read_bytes()).hexdigest() != expected:
            raise ValueError('Unsupported original '+name)
    blob, base, count, names = definitions(game=game)
    record = blob[base+72*91:base+73*91]
    if count <= 72 or names[72] != '70-Dampen ch' or u32(record,24) != 0x43F8BC0D or record[0x42] != 27:
        raise ValueError('Dampen definition binding differs')
    with tempfile.TemporaryDirectory(prefix='monastery-dampen-') as temporary:
        path = Path(temporary)/'dampen.png'
        icon(72,path,game=game)
        image = path.read_bytes()
    target = output/'assets/lol2/generated/monastery_dampen/dampen.png'
    target.parent.mkdir(parents=True)
    target.write_bytes(image)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('game','output-root'):
        p.add_argument('--'+name,type=Path,required=True)
    a = p.parse_args()
    try:
        prepare(a.game.resolve(),a.output_root.resolve())
    except (ValueError,OSError,AssertionError,KeyError,IndexError) as error:
        p.error(str(error) or 'Source validation failed')


if __name__ == '__main__':
    main()
