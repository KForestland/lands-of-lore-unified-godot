# Chief-hut preparation with explicit inputs

The hut preparer accepts original-game, map-export and prepared Jungle scene paths:

```sh
python3 tools/prepare_jungle_chief_hut.py --game-root "$GAME" --map-root "$JUNGLE_MAP" --jungle-review "$JUNGLE_REVIEW" --output-root "$FRESH_OUTPUT"
```

`JUNGLE_MAP` must contain `geometry/geometry.json`, `materials/texture.bin`, `materials/materials.json` and the referenced material images for L4_HJ. `JUNGLE_REVIEW` must contain the prepared `jungle.json` and its referenced material PNGs. It is an explicit generated prerequisite: the hut command does not create that scene assembly. Historical defaults remain for existing callers; use all flags for portable preparation. Requires Pillow, NumPy and FFmpeg. The original executable supplies the checked rotation constants through `lol2_rotation_table.py`; no historical rotation-table file is needed.

The command requires a fresh output root. It checks required top-level files, the original area archive and the original executable before creating it. Later decoding or missing subordinate inputs can leave partial output in that new root; preserve failed output for diagnosis and use another fresh directory for a new attempt. The generated `assets/lol2/generated/jungle_chief_hut` is the runtime pack; the extracted `HUT-FIRE.VQA` at the output root is an intermediate and should not be staged into the game.

An independent run with freshly derived map inputs and the explicitly supplied historical Jungle scene reproduced all 143 hut files byte-for-byte, including 60 movie frames. Missing game/map/scene inputs failed without creating output, and an existing output was refused unchanged. Neither Capstone nor native RE modules were imported. This verifies the hut assembly command; clean generation of the prerequisite Jungle scene remains separate. It does not establish audible playback or native visual parity.

The shared `prepare_jungle_exit_encounter.predicate()` reader no longer imports native verification helpers. Its standalone `main()` still imports those helpers and performs the same native checks; this change does not make that entire native audit portable.

## Separate chief-hut audio pack

The published shared AUD preparer reproduces the seven additional room cues and their manifest:

```sh
python3 -S tools/prepare_creature_audio_clips.py \
  --game /path/to/original/game \
  --output-root /path/to/fresh/hut_audio \
  --folder jungle_chief_hut_audio \
  --request 490 --request 411 --request 741 \
  --request 1025 --request 1026 --request 1027 --request 1028
```

Independent regeneration matched all eight files in `assets/lol2/generated/jungle_chief_hut_audio` byte for byte, using only the two published audio/MIX reader files and ffmpeg. This is separate from the 143-file chief-hut scene pack. Use a fresh output root: this shared audio command itself can write into an existing root. Original AUD caches stay private under `tmp`; audible playback and room timing remain separate checks.
