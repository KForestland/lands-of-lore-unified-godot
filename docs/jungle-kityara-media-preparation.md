# Kityara media preparation

Rebuild the original movie and dropped-item icon using the published source contract:

```sh
python3 tools/prepare_jungle_kityara.py --media-only \
  --game /path/to/original/game \
  --source scripts/lol2/jungle_kityara_source.json \
  --output-root /path/to/fresh/kityara
```

This path needs the portable item-icon helper and optional sprite-helper lookup fix, plus Pillow, NumPy and ffmpeg/ffprobe. Original Jungle archive, GLOBAL definitions and movie hash/segments are checked against the supported source before output. It reads the source contract without replacing it. Geometry and assembly reports are not inputs to media-only extraction.

The fresh root receives `assets/lol2/generated/jungle_kityara_media` (1,102 files) and `assets/lol2/generated/jungle_kityara/empty_hand.png`. Independent regeneration matched all 1,103 files exactly with no RE, Capstone or Unicorn imports. Three negative controls covered missing game files, a mismatched movie contract and existing output. A first private run used the wrong icon filename; after correcting it to the actual runtime path, the complete extraction was repeated in a fresh root.

The historical contract-generation CLI and its icon/media function bodies remain unchanged; research imports needed only for contract generation now load inside that entry point. No new source or native-behavior proof is claimed. Run normal Python without `-O` so reader assertions remain enabled. Writes after preflight are sequential and may leave partial fresh output on failure. Original movies, caches and generated media remain private; byte equality does not establish audible or rendered playback.
