# Cave static-prop preparation

```sh
python3 tools/prepare_cave_props_media.py --game /path/to/original-game --texture /path/to/fresh/L1_DC/materials/texture.bin --output-root /path/to/fresh-output
```

Requires Python3, Pillow and the published source/material/sprite readers. Prepare the texture using the published map-material exporter for L1_DC. Original Cave archive and texture hashes are pinned. Output must be absent and cannot overlap inputs; decoding completes before output creation.

This reconstructs the existing prop_review pack:19 first-mip PNGs plus props.json with1183 placements. It preserves the legacy selected-template set, source placement/state dimensions, trims, frame flags and region-height formula. Images use the published row-span decoder and the existing index-zero transparency convention. No historical generated input or native replay is required.

Independent isolated generation matches all20 files byte for byte. The shared readers load no native/RE modules. Four refusal controls cover existing output, missing originals, input overlap and incorrect texture. Original anchors, billboard and preview assumptions remain unchanged; neither native rendering nor gameplay interaction parity is newly claimed. Historical export and verification scripts remain untouched. This pack also supplies inputs to indexed-surface preparation; whole clean assembly and final acceptance are still separate gates.
