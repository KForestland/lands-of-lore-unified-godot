# Additional Jungle movie preparation

Two existing published preparers were independently run with original game files and repository-local helpers. The shared sprite helper must include its optional RE-root fix. Dependencies are Pillow, NumPy and ffmpeg/ffprobe. Use fresh output directories and the published source contract.

```sh
python3 tools/prepare_jungle_bacatta65_media.py \
  --game /path/to/original/game \
  --texture /path/to/fresh/L4_HJ/materials/texture.bin \
  --source scripts/lol2/jungle_bacatta65_source.json \
  --output-root /path/to/fresh/bacatta65
python3 tools/prepare_jungle_drunk_media.py \
  --game /path/to/original/game \
  --output /path/to/fresh/drunk
```

Bacatta65 writes `assets/lol2/generated/jungle_bacatta65_media` under its root; all 2,404 files reproduced exactly. Drunk writes `media` under its output; place those 584 files in `assets/lol2/generated/jungle_drunk_media` during assembly. All 584 runtime files reproduced exactly. The comparison separately inventoried the baseline's 583 Godot PNG/WAV import sidecars; these extraction commands do not generate or validate imported textures/audio.

The explicit runs loaded no RE checkout, Capstone or Unicorn modules. Original movies and conversion caches remain private. These are sequential writers using fresh roots; failed conversions may leave partial outputs. Existing output roots are refused. This verifies preparation bytes, not audible or rendered playback or the entire clean Act 1 build.
