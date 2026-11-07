#!/usr/bin/env python3
"""Museum Sk-key lock sounds and narration (owner playtest 2026-10-23: "the key is in but no sound").

From the published lock records (scripts/lol2/museum_key_locks_source.json, direct L3_DH records):
- insert group: op20 (14 10 <owner> <sound u16> ...) plays sound 676 skelkey1; take group: op20 sound 677 skelkey2.
- insert op24 (18 10 <owner> <request u16> ...) requests a narration clip (sound bank index = request). The lock's kind8
  record whose value equals that request runs when it ends: either the next op24 (chain) or the end commands (op6/op9
  reset of the effect prop: the speaking stone goes away).
Writes assets/lol2/generated/museum_key_locks_audio/ (WAVs through the shared sound-bank reader) and audio.json with
per-lock insert/take sounds and narration chains.

  PYTHONPATH=tools python3 tools/prepare_museum_key_locks_audio.py --game-root GAME --project .
"""
import argparse, json, shutil, struct, sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path[:0] = [str(TOOLS)]
SOURCE = 'scripts/lol2/museum_key_locks_source.json'
FOLDER = 'museum_key_locks_audio'


def word(command, at=4): return struct.unpack_from('<H', bytes.fromhex(command), at)[0]


def lock_audio(lock):
    sounds = {}
    for group in ('insert', 'take'):
        op20 = [c for c in lock[group]['commands'] if c.startswith('14')]
        assert len(op20) == 1, (group, op20)
        sounds[group] = word(op20[0])
    events = {r['value']: r['commands'] for r in lock.get('other_records', []) if r['kind'] == 8}
    chain, pending = [], [word(c) for c in lock['insert']['commands'] if c.startswith('18')]
    while pending:
        request = pending.pop(0)
        assert request not in chain, 'narration chain loops'
        chain.append(request)
        follow = [word(c) for c in events.get(request, []) if c.startswith('18')]
        assert len(follow) <= 1
        pending += follow
    if chain: assert not any(c.startswith('18') for c in events.get(chain[-1], [])), 'chain end is not a reset'
    return dict(insert=sounds['insert'], take=sounds['take'], chain=chain,
                end=events.get(chain[-1], []) if chain else [])


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game-root', type=Path, required=True)
    p.add_argument('--project', type=Path, required=True)
    a = p.parse_args()
    from prepare_creature_audio_clips import stage_clips, BANK_HASH
    source = json.loads((a.project / SOURCE).read_text())
    locks = {lid: lock_audio(lock) for lid, lock in sorted(source['locks'].items(), key=lambda kv: int(kv[0]))}
    assert {l['insert'] for l in locks.values()} == {676} and {l['take'] for l in locks.values()} == {677}
    assert locks['88']['chain'] == [17, 18, 19, 20]
    requests = sorted({676, 677} | {r for l in locks.values() for r in l['chain']})
    out = a.project / 'assets/lol2/generated' / FOLDER
    if out.exists(): shutil.rmtree(out)
    clips = stage_clips(a.project, FOLDER, requests, game=a.game_root)
    assert clips['676']['name'] == 'skelkey1.aud' and clips['677']['name'] == 'skelkey2.aud'
    (out / 'audio.json').write_text(json.dumps(dict(
        sound_bank_sha256=BANK_HASH, source=SOURCE, locks=locks, clips=clips,
        scope='Lock op20 insert/take sounds and op24 narration chains (kind8 value == request runs on the clip end). '
              'Not hosted: the effect prop (speaking stone) picture, op24 bytes after the request (fa05 0a14), '
              'op20 bytes after the sound.'), indent=1) + '\n')
    narrated = sum(1 for l in locks.values() if l['chain'])
    print(f'PASS museum key-lock audio: {len(locks)} locks, {narrated} narrated, {len(requests)} clips')


if __name__ == '__main__':
    main()
