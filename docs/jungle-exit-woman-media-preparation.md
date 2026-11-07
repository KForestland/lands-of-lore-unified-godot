# Jungle exit-woman media preparation

Use original game files, the freshly decoded L4_HJ texture, and the published source contract:

```sh
python3 tools/prepare_jungle_exit_woman_media.py \
  --game /path/to/original/game \
  --texture /path/to/fresh/L4_HJ/materials/texture.bin \
  --source scripts/lol2/jungle_exit_woman_source.json \
  --output-root /path/to/fresh/exit_woman
```

Python, ffmpeg and ffprobe are required. The shared sprite helper must include its optional RE-root lookup fix; this media path does not require an RE checkout or native audit dependencies. Original L4_HJ archive and decoded texture pins are checked before output, alongside the selector contract and existence of L4_HJI.MIX. The original movie archive is required; its existence alone is not a hash verification.

The output pack is `assets/lol2/generated/jungle_exit_woman_media` beneath the fresh root. Independent regeneration reproduced all 883 files byte for byte: 865 PNGs, 16 WAVs and two JSON manifests. Runtime resource paths remain unchanged. Audible playback was not checked.

`tmp/jungle_exit_woman_media` beneath the output root contains private copied original movies and conversion caches. Do not publish those or the generated pack. Existing output roots are refused. Writes after preflight are sequential and may leave a partial fresh root on failure. The legacy no-argument behavior retains its historical paths.
