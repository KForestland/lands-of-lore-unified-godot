#!/usr/bin/env python3
"""Stage the legacy Jungle DINO audio pack.

Install this file as tools/prepare_jungle_dino_audio.py. With no arguments,
main() is the legacy shop dispatch: its first two statements import the clip
stager and the sound-bank receipt, and the remaining statements match the shop
preparer. Any other invocation calls portable_main().

--tools-root is the tools directory containing this program,
prepare_creature_audio_clips.py, lol2_source_format.py, and
lol2_creature_sprite_format.py. There is no default checkout and
LOL2_GAME_ROOT is not read by the portable path.

The portable path reads the published population source contract, reads kind2
frame events with published parse_states and read_events, and stages clips
with stage_clips and an explicit game. The portable path does not import the
hive boulder preparer and does not open the unpublished jungle animation
checks document.

animation_proof_sha256 written by the portable path is retained metadata: the
receipt string already stored on the legacy runtime pack. The nine reference
rows are recomputed from the metadata event table.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

# Retained metadata: the animation_proof_sha256 string already stored on the
# legacy runtime pack. The portable path copies it and does not recompute it.
# Reference rows are separate evidence from the metadata event table.
LEGACY_PACK_ANIMATION_RECEIPT = 'c43fa3e10fc16879884f7009c2def458faa71ef0d525b6d91eee830453cc1b5b'
NAMES = {
    351: 'bigfoot1.aud',
    353: 'bigfoot3.aud',
    354: 'bigfoot4.aud',
    651: 'rat2.aud',
    978: 'dinoatk1.aud',
    979: 'dinohrt1.aud',
}
SCOPE = (
    'Six pinned sound-bank records referenced by DINO kind2 frame events. '
    'AUD chunk extents and decoded PCM sizes checked; WAV round trips preserve PCM. '
    'Known terminal demux diagnostics retained. No live playback, native volume/spatial '
    'attenuation, pause/save/restore, mixing or timing conversion acceptance.'
)

stage_clips = BANK_HASH = parse_mix = parse_states = read_events = None


def sha(raw): return hashlib.sha256(raw).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256_hex(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def bind(tools_root: Path) -> None:
    """Load the published clip stager and creature metadata readers."""
    global stage_clips, BANK_HASH, parse_mix, parse_states, read_events
    tools_root = tools_root.resolve()
    needed = (
        tools_root / 'prepare_creature_audio_clips.py',
        tools_root / 'lol2_source_format.py',
        tools_root / 'lol2_creature_sprite_format.py',
    )
    missing = [str(path) for path in needed if not path.is_file()]
    if missing:
        raise ValueError('Missing published helper: ' + missing[0])
    entry = str(tools_root)
    if entry not in sys.path:
        sys.path.insert(0, entry)
    from prepare_creature_audio_clips import BANK_HASH as bank_hash
    from prepare_creature_audio_clips import stage_clips as stage
    from lol2_creature_sprite_format import parse_states as states
    from lol2_creature_sprite_format import read_events as events
    from lol2_source_format import parse_mix as mix
    stage_clips, BANK_HASH = stage, bank_hash
    parse_mix, parse_states, read_events = mix, states, events


def sound_references(game_root: Path, source_path: Path) -> tuple[dict, list[dict], list[int]]:
    """Return the archive pin, kind2 references, and sorted sound requests."""
    contract = json.loads(source_path.read_text())
    source = contract.get('source')
    require(isinstance(source, dict), f'{source_path}: source contract has no archive pin')
    for key in ('file', 'sha256', 'geometry_key', 'geometry_sha256'):
        require(key in source, f'{source_path}: source contract misses {key}')
    actors = contract.get('actors')
    require(isinstance(actors, list), f'{source_path}: source contract has no DINO actor list')
    actor_ids = [row.get('actor') for row in actors if isinstance(row, dict)]
    require(actor_ids == list(range(21, 36)), f'{source_path}: DINO actors are not 21 through 35')
    clips = contract.get('clips')
    require(isinstance(clips, dict), f'{source_path}: source contract has no animation clips')
    require(clips.get('walk', {}).get('selector') == 1, f'{source_path}: walk selector is not 1')
    require(clips.get('bite', {}).get('selector') == 4 and clips.get('bite', {}).get('hit_frame') == 9,
            f'{source_path}: bite selector/hit frame does not match the published contract')
    require(clips.get('death', {}).get('selector') == 8, f'{source_path}: death selector is not 8')
    archive_path = game_root / source['file']
    require(archive_path.is_file(), f'missing archive: {archive_path}')
    archive = archive_path.read_bytes()
    require(sha256_hex(archive) == source['sha256'], f'{source["file"]}: unsupported or changed archive')
    entries = parse_mix(archive)
    geometry_rows = [row for row in entries if row['key'] == source['geometry_key']]
    require(len(geometry_rows) == 1, f'{source["file"]}: expected one geometry entry')
    geometry = geometry_rows[0]
    geometry_bytes = archive[geometry['offset']:geometry['offset'] + geometry['size']]
    require(sha256_hex(geometry_bytes) == source['geometry_sha256'],
            f'{source["file"]}: geometry does not match the published source contract')
    metadata = [
        archive[row['offset']:row['offset'] + row['size']]
        for row in entries
        if archive[row['offset']:row['offset'] + 8] == struct.pack('<II', 18, 516)
    ]
    require(len(metadata) == 1, f'{source["file"]}: expected one creature metadata entry')
    meta = metadata[0]
    parsed = parse_states(meta)
    dinos = [entity for entity in parsed['entities'] if entity['name'] == 'DINO']
    require(len(dinos) == 1, f'{source["file"]}: expected one DINO definition')
    dino = dinos[0]
    event_count, event_offset = struct.unpack_from('<II', meta, 0x50)
    require(event_offset + event_count * 8 + 1 == len(meta), 'DINO event table extent does not match metadata')
    references = []
    for state in dino['states']:
        raw = bytes.fromhex(state['raw_hex'])
        event_rows, _stop = read_events(meta, event_offset, event_count, struct.unpack_from('<H', raw, 8)[0])
        for event in event_rows:
            if event['kind'] != 2:
                continue
            references.append(dict(
                selector=state['selector'], frame=event['frame'],
                request=event['value_word'], source_offset=event['source_offset']))
    requests = sorted({row['request'] for row in references})
    require(requests == sorted(NAMES), 'DINO kind2 sound requests do not match the legacy six-clip pack')
    return {
        'file': source['file'],
        'sha256': source['sha256'],
        'geometry_key': source['geometry_key'],
        'geometry_sha256': source['geometry_sha256'],
        'metadata_sha256': sha256_hex(meta),
        'definition_record': dino['record'],
    }, references, requests


def _overlaps(left: Path, right: Path) -> bool:
    left, right = left.resolve(), right.resolve()
    return left == right or left in right.parents or right in left.parents


def prepare(game_root: Path, source_path: Path, output_root: Path) -> dict:
    pin, references, requests = sound_references(game_root, source_path)
    clips = stage_clips(output_root, 'jungle_dino_audio', requests, NAMES, game=game_root)
    report = dict(
        version=1,
        sound_bank_sha256=BANK_HASH,
        animation_proof_sha256=LEGACY_PACK_ANIMATION_RECEIPT,
        references=references,
        clips=clips,
        scope=SCOPE,
    )
    output = output_root / 'assets/lol2/generated/jungle_dino_audio'
    (output / 'audio.json').write_text(json.dumps(report, indent=2) + '\n')
    return {'pin': pin, 'references': len(references), 'clips': len(clips)}


def main():
    from prepare_creature_audio_clips import stage_clips
    from prepare_hive_boulder_audio import BANK_HASH
    proof=json.loads((ROOT/'docs/jungle-dino-animation-checks.json').read_text())
    references=[dict(selector=c['selector'],frame=e['frame'],request=e['value_word'],source_offset=e['source_offset']) for c in proof['clips'] for e in c['events'] if e['kind']==2]
    requests=sorted({r['request'] for r in references})
    assert requests==[351,353,354,651,978,979]
    clips=stage_clips(ROOT,'jungle_dino_audio',requests,{351:'bigfoot1.aud',353:'bigfoot3.aud',354:'bigfoot4.aud',651:'rat2.aud',978:'dinoatk1.aud',979:'dinohrt1.aud'})
    output=ROOT/'assets/lol2/generated/jungle_dino_audio'
    report=dict(version=1,sound_bank_sha256=BANK_HASH,animation_proof_sha256=sha((ROOT/'docs/jungle-dino-animation-checks.json').read_bytes()),references=references,clips=clips,
        scope='Six pinned sound-bank records referenced by DINO kind2 frame events. AUD chunk extents and decoded PCM sizes checked; WAV round trips preserve PCM. Known terminal demux diagnostics retained. No live playback, native volume/spatial attenuation, pause/save/restore, mixing or timing conversion acceptance.')
    (output/'audio.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'docs/jungle-dino-audio-checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'PASS: {len(clips)} original DINO sound clips, {len(references)} source frame bindings and PCM/WAV round trips')


def portable_main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, required=True,
                        help='Original game directory containing LOCALLNG.MIX and the source archive.')
    parser.add_argument('--source', type=Path, required=True,
                        help='Published scripts/lol2/jungle_dino_population_source.json contract.')
    parser.add_argument('--tools-root', type=Path, required=True,
                        help='Tools directory containing this program and the three published helpers. No default checkout.')
    parser.add_argument('--output-root', type=Path, required=True,
                        help='Fresh directory. The pack is written at assets/lol2/generated/jungle_dino_audio/.')
    args = parser.parse_args()
    if args.output_root.exists():
        parser.error('--output-root must be a fresh directory')
    for label, path in (('game', args.game_root), ('source', args.source), ('tools', args.tools_root)):
        if not path.exists():
            parser.error(f'Missing {label} path: {path}')
        if _overlaps(args.output_root, path):
            parser.error(f'--output-root overlaps the {label} path')
    try:
        bind(args.tools_root)
        summary = prepare(args.game_root, args.source, args.output_root)
    except (ValueError, OSError) as exc:
        print(f'prepare_jungle_dino_audio.py: error: {exc}', file=sys.stderr)
        raise SystemExit(1) from None
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    if len(sys.argv) == 1:
        main()
    else:
        portable_main()
