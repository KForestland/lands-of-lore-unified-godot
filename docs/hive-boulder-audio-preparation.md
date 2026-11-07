# Hive boulder audio preparation

Run from the source checkout, supplying original game files and a fresh output directory:

```sh
python3 tools/prepare_hive_boulder_audio.py \
  --game-root /path/to/game \
  --source docs/game-geometry-profiles.json \
  --tools-root tools \
  --output-root /path/to/fresh-output
```

The explicit path needs Python 3, ffmpeg, and the published `prepare_creature_audio_clips.py` and `lol2_source_format.py` helpers. It does not load the native executioner verifier, atlas reader, wax preparer, or a reverse-engineering checkout. No-argument dispatch preserves the historical producer and its dependencies.

The command verifies the Hive archive and geometry against the published profile and the sound bank against its existing hash. It locates four pinned command payloads in the original archive, recomputes their offsets and prop 77/234 positions, and decodes requests 704, 701 and 709. The recorded payload selections remain fixed; this is not new native execution evidence. Decoded sample counts are checked against encoded chunk sizes without padding declared extra samples.

Outputs are three WAV files and `audio.json` under `assets/lol2/generated/hive_boulder_audio`, a source receipt under `docs`, and intermediate AUD files under `tmp`. Keep original media and generated outputs local. Existing output roots, missing inputs and overlapping input/output paths are refused. A later decoding failure can leave a partial fresh output; preserve it and retry with a new directory.

Independent local review reproduced all four runtime files and the historical source receipt byte-for-byte. A second isolated rebuild used only the two published helpers with the legacy game fallback disabled and reproduced the same four files. Existing output, missing game, overlapping output and wrong archive-contract controls failed as expected. The legacy main body is AST-identical after moving three imports into that entry point. The explicit path requires the current known ffmpeg terminal diagnostic pair as well as exact PCM counts; a different decoder diagnostic format may require review.

This verifies preparation of the existing pack. Native playback, looping, attenuation and owner-removal semantics are not established by this extraction. It does not change the verified R18 runtime or establish full Act 1 asset assembly.
