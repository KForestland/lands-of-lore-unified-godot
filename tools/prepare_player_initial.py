#!/usr/bin/env python3
"""Stage recorded initial progression after verifying its original executable/code pins."""
import argparse
import hashlib
import json
from pathlib import Path

RECIPE_SHA = '9488ef3c74f5b43e86fc48bfa52e4057a7d6b7d1975b08428e9a30465eca5f31'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def prepare(game, recipe_path, output):
    if output.exists():
        raise ValueError('Output must be a fresh directory')
    for path in (game, recipe_path):
        if not path.exists():
            raise ValueError(f'Missing input: {path}')
        if output == path or output in path.parents or path in output.parents:
            raise ValueError(f'Output overlaps input: {path}')
    raw = recipe_path.read_bytes()
    if sha(raw) != RECIPE_SHA:
        raise ValueError('Unsupported recorded initialization recipe')
    recipe = json.loads(raw)
    exe = (game / 'LOLG.DAT').read_bytes()
    if sha(exe) != recipe['executable_sha256']:
        raise ValueError('Unsupported executable')
    for span in recipe['code']:
        if sha(exe[span['start'] + 0x37000:span['end'] + 0x37000]) != span['sha256']:
            raise ValueError('Initializer code span differs')
    data = {key: recipe[key] for key in ('version', 'executable_sha256', 'fighting', 'magic')}
    target = output / 'assets/lol2/generated/player_progression_initial.json'
    target.parent.mkdir(parents=True)
    target.write_text(json.dumps(data, indent=2) + '\n')
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('game', 'recipe', 'output-root'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        target = prepare(args.game.resolve(), args.recipe.resolve(), args.output_root.resolve())
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(f'PASS recorded progression packet: {target}')


if __name__ == '__main__':
    main()
