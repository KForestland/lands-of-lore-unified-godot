# Museum and Hive prop-pack preparation

```sh
python3 tools/prepare_level_props_media.py --level museum --game /path/to/original/game --output-root /path/to/fresh/museum-output
python3 tools/prepare_level_props_media.py --level hive --game /path/to/original/game --output-root /path/to/fresh/hive-output
```

These commands prepare complete `museum_props` and `hive_props` directories beneath `assets/lol2/generated`. They use original level archives, fresh material export, published source/material/sprite readers, Pillow and `docs/game-geometry-profiles.json`. No historical generated texture/prop export or constructor replay is required.

The exporter preserves source template/state/frame selection, placement records, bounds, ordinary sprite decoding and selected decorative sequences. Museum output contains 86 files and 102 placements; Hive output contains 13 files and 221 placements. Both catalogs remain byte-identical to the existing runtime catalogs.

The Hive directory includes an unreferenced `prop_62_frame_0.png` from an earlier export. Lead verification found it byte-identical to the independently prepared quest-pillar PNG. The new command decodes that first frame directly from original resource 62 and checks its hash, preserving the directory without a historical copy or catalog change.

Independent preparation reproduced every file byte-for-byte. All staged placement/template pairs also agree with a separate fresh published prop export. Reader ASTs agree with their historical equivalents. Isolated committed-source runs loaded no native/RE modules; eight refusal controls cover existing output, overlap, missing originals and wrong archives for both levels.

Output must be fresh and outside the original game directory. Images are encoded before final writes. Both legacy writers/CLIs remain unchanged. Index-zero alpha, fixed-Y billboarding and 10-fps decorative loops retain their existing review meaning; activation, collision, interaction and native rendering parity are not newly verified.
