# Cave captain media preparation

Use fresh Cave geometry and decoded texture with the published profiles and runtime contracts:

```sh
python3 tools/prepare_cave_captain_movie.py \
  --game /path/to/original/game \
  --geometry /path/to/fresh/L1_DC/geometry/geometry.json \
  --texture /path/to/fresh/L1_DC/materials/texture.bin \
  --source-root /path/to/source-checkout \
  --output-root /path/to/fresh/captain
```

Generate the geometry and texture using the published preparation tools described in [source reproduction](act1-source-reproduction.md). This path requires `docs/game-geometry-profiles.json`, `scripts/lol2/cave_captain_source.json` and `scripts/lol2/cave_support_controls_source.json` in the source checkout. It uses Pillow, NumPy and ffmpeg/ffprobe through the local readers.

The preparer reads the original 60-byte template27 directly from the pinned Cave metadata, checks its dimensions and movie resource, and derives the six captain-admission polygons from fresh geometry and the published kind10 records. Those records are checked against the original actor56 event list. The geometry is bound to the source archive hash; as with other preparation inputs, it must come from the verified exporter. This does not rerun the native admission scanner or certify arbitrary edited geometry.

Independent regeneration matched all 159 movie-pack files plus the separate `cave_captain_audio/1031.wav` exactly. The output roots are `assets/lol2/generated/cave_captain_movie` and `assets/lol2/generated/cave_captain_audio`; speech metadata remains in the movie manifest. The missing-game, wrong-texture, wrong-geometry-source, incomplete argument pair and existing-output controls failed without altering prior output.

The historical `--map` path remains supported and was separately executed with its existing inventory/admission/movable reports; both complete packs matched the new path. It is mutually exclusive with `--geometry`/`--texture`. No new native replay or audible/rendered review was performed.

Use fresh output and normal Python without `-O` to retain source assertions. Portable source/region/texture validation runs before media staging; later template, movie or I/O failure can leave partial fresh output. Original movies, AUD caches and generated packs remain private.
