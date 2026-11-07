#!/usr/bin/env python3
"""Extract the existing Fine Longsword request packet without replaying its callback."""
import argparse
import hashlib
import json
from pathlib import Path
from lol2_source_format import parse_mix, u32


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def prepare(game, output):
    if output.exists():
        raise ValueError('Output must be a fresh directory')
    if output == game or output in game.parents or game in output.parents:
        raise ValueError('Output overlaps original game')
    archive = (game / 'GLOBAL.MIX').read_bytes()
    if sha(archive) != '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd':
        raise ValueError('Unsupported GLOBAL archive')
    entries = [e for e in parse_mix(archive) if e['key'] == 3984507021]
    if len(entries) != 1:
        raise ValueError('Expected one definitions entry')
    entry = entries[0]
    blob = archive[entry['offset']:entry['offset'] + entry['size']]
    if sha(blob) != 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891':
        raise ValueError('Unsupported definitions')
    offset = u32(blob, 4) + 5 * 91
    definition = blob[offset:offset + 91]
    identity = u32(definition, 24)
    mask = int.from_bytes(definition[0x3b:0x3d], 'little')
    signature = int.from_bytes(definition[0x3d:0x3f], 'little')
    handler = definition[0x42]
    if (identity, mask, signature, handler) != (0xe18240be, 2, 4, 0):
        raise ValueError('Fine Longsword definition differs')
    data = dict(version=1, definition=5, identity=identity, label='Fine_Longsword',
                mask=mask, signature=signature, handler=handler,
                source=dict(file='GLOBAL.MIX', sha256=sha(archive), key=entry['key'],
                            definition_archive_offset=entry['offset'] + offset,
                            definition_sha256=sha(definition)))
    target = output / 'assets/lol2/generated/hive_fine_longsword_request.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(data, indent=2) + '\n')
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        target = prepare(args.game.resolve(), args.output_root.resolve())
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(f'PASS original Fine Longsword request: {target}')


if __name__ == '__main__':
    main()
