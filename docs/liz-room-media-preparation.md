# LIZ room media preparation

```sh
python3 tools/prepare_liz_room_media.py \
  --game /path/to/original/game \
  --re-root /path/to/lands-of-lore-2-re \
  --source scripts/lol2/liz_room_source.json \
  --output-root /path/to/fresh/liz
```

This explicit path uses the tracked LIZ source contract, `monastery_media.py`, `decode_monastery_vectors.py`, published local readers and the same pinned companion converter described in [monastery preparation](monastery-room-media-preparation.md). Pillow and ffmpeg/ffprobe are required. No additional recorded recipe or native audit is needed.

The original LIZ and localized archives, background/intro entries, source contract and sound-bank bindings are checked before writing. Every cue is checked against its original row-addressed bytes, size and hash. Four independent negative controls rejected an existing output, missing game files, wrong source and a re-pinned source with a changed cue request; prior output remained untouched.

The output is `assets/lol2/generated/liz_room` beneath the fresh root. Independent verification covered all 16 files: 14 PNG/WAV/manifest files were byte-identical, the 30-frame video-only background matched in decoded RGB frames and encoded packets, and its converter report differed only in absolute paths and ffmpeg pointer addresses. All 14 manifest resource paths resolved inside the fresh output. The Ogg container serial can differ. No Capstone, Unicorn or legacy room-audit module was loaded.

The no-argument/imported legacy path retains its original imports and defaults. Writes after preflight are sequential and may leave a partial fresh root on failure. Run normal Python without `-O` to preserve reader assertions. Original media and caches remain private. This changes media preparation only; optional hotspot responses, callback11 and ambient behavior remain as documented in the existing source contract. Audible playback and rendered gameplay are separate acceptance checks.
