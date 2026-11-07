# Museum hourglass preparation

```sh
python3 tools/prepare_museum_hourglass_media.py --game /path/to/original/game --output-root /path/to/fresh-output
```

Requires Python, NumPy, Pillow and the published source/material/prop/movie readers. Produces all seven files under `assets/lol2/generated/museum_hourglass`: first-frame PNG, three atlas PNGs and three JSON manifests. All seven match the existing runtime pack byte-for-byte. The final command uses only original files; no recorded-data recipe or historical generated input is needed.

The command pins the Museum and Museum movie archives, resolves HRGLASS.VQA by its original name hash, verifies descriptor477 against fresh decoded Museum texture, and derives prop226's placement/bounds/state/frame from a fresh prop export. It ports the existing verified split-plane renderer: VGA6-bit palette, LCW codebooks, eight-part updates, solid blocks, bounded vectors and three codebook checkpoints. All300frames are decoded and packed with the existing magenta-key and10×10atlas conventions. Stage names and four inclusive75-frame ranges come from the movie chunks.

Independent review rebuilt the complete pack with committed helpers and no native replay imports, and compared every rendered RGBA frame with the historical verifier's300-frame record. All300match. That historical record included a separate FFmpeg PAL8 pixel/palette comparison; FFmpeg is not an input or dependency of this preparation command. The chunk-framing function matches the published original exactly. Existing-output, missing-original, altered-archive and overlapping-output refusal controls pass.

The output must be absent and must not overlap the game tree. It is created after decoding/checks; later filesystem failures may leave partial output. Original/generated media are excluded from source publication. The legacy producers remain unchanged. This preserves existing content and its stated scope: magenta transparency, billboard presentation and event-to-frame choices retain their restoration conventions; no new native event timing or gameplay parity is claimed. Whole-build rendered qualification remains separate.
