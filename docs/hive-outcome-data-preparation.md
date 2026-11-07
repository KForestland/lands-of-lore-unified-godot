# Hive outcome animation-data preparation

```sh
python3 tools/lol2/map_materials.py export --game-root /path/to/original/game --area L5_HC --out /path/to/fresh/materials
python3 tools/prepare_hive_outcome_data.py --game /path/to/original/game --texture /path/to/fresh/materials/texture.bin --output-root /path/to/fresh/output
```

The first command requires the published geometry profile. The second needs only three published source/material/creature readers. It checks the original Hive archive, executable provenance and fresh texture hashes, then prepares the complete `assets/lol2/generated/hive_outcome/animation.json`.

Original definition 1 (`EXEC`) provides selectors 17–20. Their resources are 474, 742, 336 and 334, with 19/9/1/1 frames. Counts come from the source texture descriptor groups or sprite descriptor; intervals and frame events come from metadata. The existing selector-to-action labels 14/15 are preserved. Executable provenance is checked without executing native code.

Output must be absent and must not overlap either input. All extraction checks precede writing. Lead verification reproduced the entire runtime JSON byte-for-byte with an isolated tool and three-reader closure. Six controls refused existing output, overlapping output, missing originals, wrong texture, wrong executable and wrong archive without new output.

The historical native animation verifier and replay fixtures remain unchanged. This command does not rerun the native frame-count getter, animation loop, outcome admission or live timing. Existing replay evidence remains separate from this reproducible data extraction.
