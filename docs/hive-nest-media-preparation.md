# Hive nest media preparation

Prepare the existing nest pack with explicit original and freshly prepared inputs:

```sh
python3 tools/prepare_hive_nest_media.py --game /path/to/original/game \
  --geometry /path/to/fresh/L5_HC/geometry/geometry.json \
  --texture /path/to/fresh/L5_HC/materials/texture.bin \
  --output-root /path/to/fresh-output
```

The geometry must be the L5_HC export with ceiling subdivisions applied. The command checks its area/archive/geometry-entry binding, original Hive archive and decoded texture hashes. It uses the original EX07/EX08 movie entries, the published state parser and block-sprite decoder, and six source approach regions. Pillow, NumPy and FFmpeg are required; the media command itself needs no RE checkout or native-audit package.

Output is `assets/lol2/generated/hive_nest`: two atlases containing 64 movie frames, the original Executioner pose and `nest.json`. Intermediate movies and decoder logs stay beneath `tmp/hive_nest`. The existing 320×200 canvas, eight-column atlas layout and cyan transparency key are preserved.

Independent fresh preparation reproduced all four runtime files byte-identically, including movie/pose metadata, source positions and approach polygons. Existing-output, wrong-area geometry, wrong texture and overlapping-input controls rejected without modifying output. Geometry source binding is checked; this command does not independently regenerate every supplied vertex and height. Use the fresh geometry pipeline, not an edited geometry document.

Initial selector zero, completion selector two/resource433 and the authored size/baseline anchors retain their historical meanings. Original state/resource bindings are checked, but this preparation does not repeat native activation, callback, combat or scheduling proofs. The historical `prepare_hive_nest.py` remains unchanged.

Output must be fresh and outside input directories. Later movie or sprite decoder failures can leave partial output for diagnosis. Run ordinary Python without optimization because decoder checks include assertions. This pack-specific recipe does not complete clean preparation of the whole Hive or Act 1.
