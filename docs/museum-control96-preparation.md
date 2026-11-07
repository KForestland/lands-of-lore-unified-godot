# Museum control96 media preparation

Prepare the original SG17 movie and its assembly surfaces with explicit inputs:

```sh
python3 tools/prepare_museum_control96_media.py --game /path/to/original/game \
  --assembly /path/to/fresh/museum/static_assembly/movables.json \
  --texture /path/to/fresh/museum/materials/texture.bin \
  --source scripts/lol2/museum_control96_source.json \
  --output-root /path/to/fresh-output
```

Generate the L3_DH static assembly with [the movable exporter](map-movables-preparation.md), using fresh Museum materials. Its `materials_root` must resolve the referenced images. The preparer checks the published contract pin, original archive and executable hashes, selected placements, faces, texture descriptor and original movie binding. It checks the recorded receiver code span without replaying the historical executable fixup walk or handlers. The source contract is consumed unchanged.

Dependencies are Pillow, FFmpeg and the repository-local movie, source and sprite readers. The media command needs no RE helper root; the prerequisite assembly export has the separate documented helper requirements. The output root must be new and outside input directories. A decode failure may leave partial fresh output for diagnosis.

Fresh extraction reproduced all 71 runtime files byte-identically: 68 keyed movie frames, two surface textures and `source.json`. The movie retains the existing 90-degree clockwise presentation rotation and cyan transparency key. Those adapters are not native decoder or renderer equivalence claims. Existing-output and incorrect-contract controls preserve output; further input checks reject mismatched geometry or missing materials before staging.

This command writes only `assets/lol2/generated/museum_control96` and an intermediate movie/frame cache under `tmp`. The historical `prepare_museum_control96.py` remains unchanged. Full Museum assembly, live rendering admission, timing and broader gameplay acceptance are separate.
