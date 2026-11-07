# Cave-eye animation and sound preparation

Cave actor 24 needs a special 10-frame idle sequence and 23-frame moving sequence. The generic creature command alone leaves these two 0x2c6 sequences unsupported. The existing cave-eye preparer now exposes its media step with explicit inputs, preserving the same frame expansion:

```sh
python3 -S tools/decode_level_texture.py --game "$GAME" --area L1_DC --output "$FRESH_TEXTURE"
python3 tools/prepare_cave_eyes.py --game "$GAME" --texture "$FRESH_TEXTURE/texture.bin" --output-root "$FRESH_OUTPUT"
```

Requires Pillow and FFmpeg; texture extraction additionally needs system `liblzo2`. The media command needs neither an RE checkout nor Capstone. Older native-audit callers still resolve the checkout when it exists; an explicitly invalid `LOL2_RE_ROOT` remains an error. Originals are checked against the existing area, decoded-texture and audio-bank identities before output is created. Use fresh output directories; existing output is refused. Later I/O or decode failures may leave partial files in a new output root.

The result contains `assets/lol2/generated/cave_eyes` (33 indexed PNGs, palette and sprite manifest) and `assets/lol2/generated/cave_eyes_audio` (`232.wav` and audio manifest). Copy these directories into a fresh asset assembly at the same relative paths. Intermediate AUD data under `tmp` is not runtime media. Keep the already tracked `scripts/lol2/cave_eyes_source.json`; this command does not regenerate lifecycle or path behavior.

Independent preparation reproduced all 37 runtime files byte-for-byte from original archives and a freshly decoded Cave texture. Missing game/audio inputs, a modified texture and existing output were rejected; prior output stayed unchanged. No-argument invocation retains the full source/native audit, with its original external dependencies and native assertions. That native audit was not rerun for this media-only change. This is preparation evidence, not a new gameplay or audible-playback claim.
