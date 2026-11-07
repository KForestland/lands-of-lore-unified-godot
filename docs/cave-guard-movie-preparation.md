# Cave guard-control movie preparation

The published movie preparer accepts original game files and the published source contract directly:

```sh
python3 tools/prepare_cave_guard_controls_media.py \
  --game /path/to/original/game \
  --source scripts/lol2/cave_guard_controls_source.json \
  --output-root /path/to/fresh/guard_movies
```

It needs the repository's movie readers, Pillow, NumPy and ffmpeg/ffprobe. An independent run from the published tool tree, with the historical RE checkout unavailable, reproduced all 285 files in `assets/lol2/generated/cave_guard_controls` byte for byte. No RE, Capstone or Unicorn modules were loaded. The four clips contain 30, 26, 60 and 164 frames; original movie hashes, dimensions, matte colors and PCM sample counts retain their checks.

The output root must be fresh. Original VQAs and conversion caches remain under its private `tmp` directory. The writer creates output before all movie decoding is complete, so a later failure can leave a partial fresh root. Run normal Python without `-O` to preserve assertion checks. This verifies preparation bytes, not audible playback or native encounter timing.
