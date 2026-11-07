# Scenic-guard explosion and audio preparation

The existing published preparer can rebuild both complete runtime packs after fresh L1_DC prop and movable preparation. Supply a fresh map directory containing `props/sprites` and `movables/movables.json`:

```sh
python3 tools/lol2/map_props.py export --game-root "$GAME" --area L1_DC \
  --material-root "$MATERIALS" --out "$MAP/props"
python3 tools/export_map_movables.py --game-root "$GAME" --area L1_DC \
  --placement-kind movable --material-root "$MATERIALS" --re-root "$RE" \
  --tools-root "$TOOLS" --out "$MAP/movables"
python3 tools/prepare_cave_scenic_guard_movie.py --game "$GAME" --map "$MAP" \
  --source scripts/lol2/cave_scenic_guard_source.json \
  --inventory docs/game-geometry-profiles.json --output-root "$OUTPUT"
```

`GAME` is the supported original installation, `MATERIALS` its freshly decoded L1_DC materials directory, `RE` the published helper checkout, `TOOLS` this checkout's tools directory, and `MAP`/`OUTPUT` new private preparation locations. The [movable recipe](map-movables-preparation.md) lists its helper closure. Pillow and FFmpeg are required. The published geometry profiles supply the archive binding; the larger historical source inventory is unnecessary for this command.

Independent regeneration used fresh original-derived props and a separately verified fresh movable report. All 98 files in `cave_scenic_guard_movie` and both WAVs in `cave_scenic_guard_audio` matched existing output byte-for-byte, including 90 explosion frames, source audio, oil-fire index frames and metadata. This verifies the complete two packs; it does not replace the separate scenic-guard creature sprite recipe.

The producer creates its fresh output before all later input and decode checks. Failures can leave partial output. Its CLI refuses an existing output root, and no-argument historical behavior remains unchanged. This is preparation evidence, not live presentation, audible quality, native timing or whole-Act-1 acceptance.
