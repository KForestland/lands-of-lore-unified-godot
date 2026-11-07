#!/usr/bin/env python3
"""Hive lift call posts 126-132: every press (control event3, value 0 or 1; groups 8212-8498) runs op20 sound 388 at
the post, then op5 control125 mode <stop>. Stages that click through the shared sound-bank reader (owner playtest
2026-10-23 20:36:13: "button do not work" with the lift already at that stop: the original still clicks).

  PYTHONPATH=tools python3 tools/prepare_hive_elevator_audio.py --game-root GAME --project .
"""
import argparse, json, shutil, struct, sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path[:0] = [str(TOOLS)]


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game-root', type=Path, required=True)
    p.add_argument('--project', type=Path, required=True)
    a = p.parse_args()
    from verify_actor_item_grants import source_area
    from prepare_creature_audio_clips import stage_clips, BANK_HASH
    _, _, _, _, owners, streams = source_area('L5_HC', a.game_root.resolve())
    posts = {}
    for o in owners:
        if o['owner_kind'] == 'control' and 126 <= o['owner'] <= 132 and o['event'] == 3:
            cmds = [c['raw_hex'] for c in streams[o['stream']][o['group']]]
            sounds = [struct.unpack_from('<H', bytes.fromhex(c), 4)[0] for c in cmds if c.startswith('14')]
            assert sounds == [388], (o['owner'], cmds)
            posts.setdefault(str(o['owner']), []).append(o['group'])
    assert sorted(posts) == [str(n) for n in range(126, 133)] and all(len(g) == 2 for g in posts.values())
    out = a.project / 'assets/lol2/generated/hive_elevator_audio'
    if out.exists(): shutil.rmtree(out)
    clips = stage_clips(a.project, 'hive_elevator_audio', [388], game=a.game_root)
    (out / 'audio.json').write_text(json.dumps(dict(sound_bank_sha256=BANK_HASH, posts=posts, press_sound=388, clips=clips,
        scope='Call-post press click (op20 388 at the post). Not hosted: control125 stop indicators.'), indent=1) + '\n')
    print(f"PASS hive elevator audio: posts {sorted(posts)}, sound 388 = {clips['388']['name']}")


if __name__ == '__main__':
    main()
