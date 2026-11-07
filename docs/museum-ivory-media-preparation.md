# Museum Ivory media preparation

The media-only entry point regenerates the two urn selector PNGs and Ivory Chip icon using original archives, a freshly decoded Museum texture and the published runtime source contract:

```sh
python3 tools/prepare_museum_ivory.py --media-only \
  --game /path/to/original/game \
  --texture /path/to/fresh/L3_DH/materials/texture.bin \
  --source scripts/lol2/museum_ivory_source.json \
  --output-root /path/to/fresh/ivory
```

This requires the portable [item icon helper](item-icon-preparation.md), repository material/prop readers and Pillow. Original archive, texture and definition pins are checked before output. All three PNGs and the decoded urn bounds are checked against the published contract, which is read without modification. Output is `assets/lol2/generated/museum_ivory` beneath the fresh root; temporary prop images stay under that root and are removed on success. Generated media remains private.

Independent preparation reproduced the entire three-file pack byte for byte. Wrong texture, wrong art contract and existing output controls all refused while preserving prior output. No RE or native audit modules are imported by this media path. Run ordinary Python without `-O`, because the readers and final contract comparisons use assertions.

The existing source-generation CLI remains available and still executes its native filter replay. Its main and replay function bodies are unchanged apart from moving research imports inside those functions. Media preparation does not rerun or certify that audit. Writes after preflight are sequential; a decode, contract-comparison or I/O failure may leave a partial fresh output root.
