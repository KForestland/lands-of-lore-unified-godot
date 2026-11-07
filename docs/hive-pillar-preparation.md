# Hive quest-pillar preparation

Prepare a fresh Hive texture container, then the runtime pack:

```sh
python3 tools/lol2/map_materials.py export --game-root /path/to/original/game --area L5_HC --out /path/to/fresh/materials
python3 tools/prepare_hive_pillar_media.py --game /path/to/original/game --texture /path/to/fresh/materials/texture.bin --output-root /path/to/fresh/output
```

The material exporter requires the published geometry profile. The pillar tool requires Pillow and the published source, material, sprite, atlas and command readers. It checks the original Hive archive and texture hashes. No historical generated progression report or RE checkout is needed.

The complete `assets/lol2/generated/hive_pillar` pack contains `pillar.png` and `pillar.json`. Original prop 215 joins template 6 and sprite resource 62. Both original movement groups 10414 and 10510 must contain exactly one matching opcode 18 command addressed to prop 215, and those commands must agree. The original sprite decoding, bounds, placement and source XY operands are retained.

Output must be fresh and must not overlap either input. The image is encoded in memory; final files are written after source checks. Lead verification reproduced both complete runtime files byte-for-byte using an isolated seven-helper closure and a previously verified fresh Hive texture export. No native/RE modules were loaded. Existing output, overlapping output, missing originals, wrong archive and wrong texture were refused without new output.

The legacy writer is unchanged. Fixed-Y billboard presentation, preserved height and one-second movement remain the existing review conventions; this preparation does not newly verify collision or combat callbacks.
