# Cave lava-region preparation

```sh
python3 tools/prepare_cave_lava_data.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This prepares the complete `assets/lol2/generated/cave_lava/regions.json` using fresh geometry and material exports from original `DAT/L1_DC.MIX`. The source checkout must include the published map exporters/readers and `docs/game-geometry-profiles.json`. No historical generated review or original-floor pack is an input.

The tool reads each emitted floor's source selector and resolves the preset's material reference through the fresh texture container. Cave preset 16 has reference -1, which resolves to material 135. All 86 selected floors must be flat and have distinct region IDs. The original archive and fresh texture hashes are checked. Temporary intermediate exports are discarded; only the runtime JSON is retained.

Output must be fresh and outside the original game directory. All preparation checks run before final output is written. Lead verification reproduced the entire runtime JSON byte-for-byte, including source metadata, ordering and coordinates. An isolated committed-source run loaded no native or RE modules; existing output, missing originals, overlapping output and a wrong archive were refused without new output.

Immediate lethal grounded contact remains the existing owner-approved modern policy. This extraction does not verify native damage timing or immunities. The legacy producer and other unresolved floor materials are unchanged.
