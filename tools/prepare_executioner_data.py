#!/usr/bin/env python3
"""Extract existing Executioner health/reward packets from pinned original data."""
import argparse
import hashlib
import json
from pathlib import Path
from lol2_source_format import parse_mix, u32

ARCHIVE = 'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
EXE = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
GEOMETRY = '69a9c0dd739ad36691c6513d53cf007204aa3bd35d5762e8f8f4e8c6dbcb9e85'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def prepare(game, output):
    if output.exists():
        raise ValueError('Output must be a fresh directory')
    if output == game or output in game.parents or game in output.parents:
        raise ValueError('Output overlaps original game')
    archive = (game / 'DAT/L5_HC.MIX').read_bytes()
    if sha(archive) != ARCHIVE or sha((game / 'LOLG.DAT').read_bytes()) != EXE:
        raise ValueError('Unsupported original game data')
    entries = parse_mix(archive)
    geometry = [e for e in entries if e['key'] == 3776990464]
    if len(geometry) != 1:
        raise ValueError('Expected one geometry entry')
    ge = geometry[0]
    geo = archive[ge['offset']:ge['offset'] + ge['size']]
    if sha(geo) != GEOMETRY:
        raise ValueError('Unsupported geometry')
    candidates = []
    for entry in entries:
        raw = archive[entry['offset']:entry['offset'] + entry['size']]
        if len(raw) >= 0x50 and u32(raw, 0) == 18 and u32(raw, 4) == 516:
            candidates.append((entry, raw))
    if len(candidates) != 1:
        raise ValueError('Expected one actor metadata entry')
    me, meta = candidates[0]
    start, count = u32(geo, 0x1c), u32(geo, 0x68)
    if count <= 36 or start + count * 56 > len(geo):
        raise ValueError('Invalid actor placements')
    actor = geo[start + 36 * 56:start + 37 * 56]
    kind = actor[32]
    definition_start = u32(meta, 0x10) + kind * 147
    if kind >= u32(meta, 0x48) or definition_start + 147 > len(meta):
        raise ValueError('Invalid actor definition')
    definition = meta[definition_start:definition_start + 147]
    actor_offset = ge['offset'] + start + 36 * 56
    definition_offset = me['offset'] + definition_start
    if (kind, actor_offset, definition_offset) != (1, 5946298, 6025818):
        raise ValueError('Executioner binding differs')
    health = dict(actor=36, definition=kind,
                  source=dict(file='DAT/L5_HC.MIX', sha256=ARCHIVE,
                              geometry_key=ge['key'], geometry_sha256=GEOMETRY),
                  actor_offset=actor_offset, definition_offset=definition_offset,
                  maximum=int.from_bytes(definition[0x63:0x65], 'little'),
                  requested=int.from_bytes(actor[43:45], 'little'),
                  definition3c=definition[0x3c], definition7f=definition[0x7f], mode=0)
    scale = max(1, definition[0x83])
    if (health['maximum'], health['requested'], scale) != (300, 300, 8):
        raise ValueError('Executioner values differ')
    reward = dict(actor=36, definition=kind, definition_offset=definition_offset,
                  archive_sha256=ARCHIVE, executable_sha256=EXE, scale=scale,
                  source_field='definition+0x83 -> request+0x1A (A6C2B)',
                  source_proofs=['hive-actor-hit-handoff.json', 'hive-sword-reward-seed.json',
                                 'hive-sword-reward-scaling.json', 'hive-sword-reward-application.json'],
                  scope='Source scale and previously verified arithmetic composed with live positive melee loss and remaining health. Modern damage, RNG and health adapter; no historical awards, spell rewards or full native callback parity.')
    target = output / 'assets/lol2/generated'
    target.mkdir(parents=True)
    for name, data in [('hive_actor_health.json', health), ('executioner_melee_reward.json', reward)]:
        (target / name).write_text(json.dumps(data, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        prepare(args.game.resolve(), args.output_root.resolve())
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print('PASS original Executioner health and reward data')


if __name__ == '__main__':
    main()
