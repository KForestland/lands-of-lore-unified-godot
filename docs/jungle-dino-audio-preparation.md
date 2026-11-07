# Jungle DINO audio preparation

Install the preparer as `tools/prepare_jungle_dino_audio.py`. `--tools-root` is that tools directory. It is not a repository root and it is not a default checkout.

```
<install>/
  tools/prepare_jungle_dino_audio.py
  tools/prepare_creature_audio_clips.py
  tools/lol2_source_format.py
  tools/lol2_creature_sprite_format.py
  scripts/lol2/jungle_dino_population_source.json
```

The same filename has two dispatch arms.

## No arguments: legacy shop dispatch

```sh
python3 -B <install>/tools/prepare_jungle_dino_audio.py
```

`len(sys.argv) == 1` calls `main()`. That function is the shop preparer. Its first statement is `from prepare_creature_audio_clips import stage_clips`. Its second statement is `from prepare_hive_boulder_audio import BANK_HASH`. Those imports are inside the function, so importing this module does not load `prepare_hive_boulder_audio` or `verify_hive_executioner`. The statements after those two imports are the shop `main` statements, including the module-level `ROOT` and `sha` names that function uses.

That arm reads `docs/jungle-dino-animation-checks.json`, calls `stage_clips` without `game=`, and writes both `assets/lol2/generated/jungle_dino_audio/audio.json` and `docs/jungle-dino-audio-checks.json` under `ROOT` (`Path(__file__).resolve().parents[1]`). On the legacy arm, `animation_proof_sha256` is recomputed by hashing that checks file. The proof does not execute this arm. Executing it would import the hive boulder preparer and write those shop-relative paths.

## Flags: portable clean path

Any other invocation calls `portable_main()`.

```sh
python3 -B <install>/tools/prepare_jungle_dino_audio.py \
  --game-root /path/to/original/game \
  --source <install>/scripts/lol2/jungle_dino_population_source.json \
  --tools-root <install>/tools \
  --output-root /path/to/fresh-output
```

`--game-root`, `--source`, `--tools-root`, and `--output-root` are all required. A partial command is rejected by argparse before a pack directory is created.

## Published closure

`--tools-root` must contain:

- `prepare_jungle_dino_audio.py`
- `prepare_creature_audio_clips.py` from Godot `d6bff86f3c5f7ad75239f24480bf41a64b56893f`
- `lol2_source_format.py` from that same commit
- `lol2_creature_sprite_format.py` from that same commit

The portable path calls `stage_clips` with the explicit `game=` argument. `LOL2_GAME_ROOT` is not read. That path does not import `prepare_hive_boulder_audio` and does not open `docs/jungle-dino-animation-checks.json`. FFmpeg is the host decoder `stage_clips` already runs. Capstone is not used.

`--source` is the published `scripts/lol2/jungle_dino_population_source.json`. The preparer checks its archive file, archive sha256, geometry key, and geometry sha256, and checks that actors 21 through 35 and the walk, bite, and death selectors match that contract. Creature metadata is the single header-(18, 516) entry in that archive. `parse_states` selects the DINO definition. `read_events` supplies each state's frame events. Every kind 2 row becomes `selector`, `frame`, `request`, and `source_offset`, including selectors that the population `clips` object does not list.

## Retained receipt versus recomputed event evidence

`audio.json` has both `animation_proof_sha256` and `references`. They are not the same kind of evidence.

`animation_proof_sha256` (`c43fa3e10fc16879884f7009c2def458faa71ef0d525b6d91eee830453cc1b5b`) is retained metadata. It is the string already stored on the legacy runtime pack. The portable writer copies that constant so the runtime file can stay byte-identical. It does not open the checks file, and it does not hash the nine event rows. The legacy no-arg arm is the path that recomputes this field from `docs/jungle-dino-animation-checks.json`. Replacing the retained string with a newly computed provenance hash would break byte equality with the shop pack.

`references` are recomputed event evidence. The portable path rebuilds those nine rows from the published metadata event table via `read_events`. The shop pack's reference rows are the comparison target. The published loader `scripts/lol2/jungle_dino_audio.gd` reads `data.clips[id].path` and `wav_sha256` only. It does not read `references` or `animation_proof_sha256`.

## Output

The fresh root receives `assets/lol2/generated/jungle_dino_audio/` with six WAV files and `audio.json`. `stage_clips` also leaves the extracted AUD files under `tmp/jungle_dino_audio/`. That cache is not part of the seven-file runtime pack.

`--output-root` must be new and must not overlap the game, source, or tools path. A missing path or an existing output root is rejected before a pack directory is created. An archive, contract, bank, or event mismatch raises before `stage_clips` creates directories, except a sound-bank failure inside `stage_clips`, which also returns before its `mkdir`. A failure during a later WAV or `audio.json` write can leave a partial tree. Checks use normal Python. `python -O` would strip the published stager's asserts. Use `python3 -B`.

No playback, attenuation, pause, or timing claim is made.
