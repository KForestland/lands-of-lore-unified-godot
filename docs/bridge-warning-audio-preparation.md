# Bridge warning audio preparation

```sh
python3 -S tools/export_bridge_warning.py \
  --game-root /path/to/original/game \
  --out /path/to/fresh/bridge_warning
```

The exporter now uses the repository-local MIX reader. It requires Python's standard library and ffmpeg. The old `--re-tools` argument remains accepted for compatibility but is unused; no RE checkout is required. The CLI refuses an existing output directory.

Both `hey_you.wav` and `provenance.json` reproduce the current runtime bytes exactly. Assemble these under **`assets/lol2/bridge_warning`**, not the generated-assets subdirectory. The existing Godot WAV import sidecar was inventoried separately; this command does not produce it.

The original localized archive, sound identity, AUD bounds, reviewed PCM hash and WAV round trip retain their checks. The source declares one more sample than the encoded nibbles supply; the existing no-padding behavior is unchanged. Missing-game and existing-output controls preserved prior output. Decode validation precedes output creation; final file writes are sequential. Original audio remains private. This preparation does not establish native trigger binding or audible playback acceptance.
