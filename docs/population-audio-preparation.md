# Population audio preparation

The shared population audio writer accepts original game files and a freshly generated sprite manifest. It verifies the original metadata and frame-event bytes, decodes the pinned sound bank, and reproduces the encounter-specific audio manifest and source contract. It needs Python's standard library and ffmpeg; no RE checkout or native audit dependencies are loaded.

```sh
python3 -S tools/prepare_museum_creature_audio.py \
  --game /path/to/original/game \
  --sprites /path/to/fresh/cave_guard_sprites/sprites.json \
  --population cave_guard_audio \
  --output-root /path/to/fresh/guard_audio
```

Prepare manifests using [creature sprite preparation](act1-creature-sprite-preparation.md). Select the matching population:

| Population | Sprite manifest folder | Definitions | Verified output files |
| --- | --- | --- | --- |
| museum_creature_audio | museum_creature_sprites | 0, 1, 2 | 15 |
| cave_guard_audio | cave_guard_sprites | 0, 1, 2 | 12 |
| cave_roach_audio | cave_roach_audio_sprites | 4, 5 | 10 |
| cave_lurking_roach_audio | cave_lurking_roach_sprites | 6 | 11 |

All 48 generated audio files and all four `scripts/lol2/*_source.json` contracts matched the current runtime bytes in independent regeneration. The output root also contains private AUD caches and verification reports. Copy only the intended runtime pack during assembly; the regenerated source contracts are comparison evidence, not automatic replacements for tracked source.

The CLI refuses existing output roots, missing inputs and mismatched population definitions. Original archive, metadata, event and sound-bank checks precede media writes; later decode or I/O failures may leave a partial fresh output. Four negative controls confirmed refusal and preservation of prior output. Existing positional Python callers and the no-argument Museum entry point retain their defaults; the legacy entry point was checked by dispatch, not a new native audit. Audible playback and native event dispatch remain separate checks.
