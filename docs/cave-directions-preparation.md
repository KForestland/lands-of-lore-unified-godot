# Cave directional creature preparation

```sh
python3 tools/prepare_cave_directions_media.py --game /path/to/original-game --texture /path/to/fresh/L1_DC/materials/texture.bin --output-root /path/to/fresh-output
```

Requires Python3, Pillow and the published source/material/sprite readers. Prepare the texture with the published map-material exporter for L1_DC. The original Cave archive, metadata entry and texture are pinned. The output root must be absent and cannot overlap an input. Decoder failure may leave a partial output; retain it for diagnosis and retry in a fresh directory.

The command reads Roach definition4 selector2's eight directional views and action5/14 links directly. It decodes81 distinct original frames, mirrors the designated views before a common lossless crop, and retains empty collapse frames. It produces the complete encounter_directions pack:108 PNGs, animation.json and bearing_fixtures.json. All110 files independently match the existing pack byte for byte.

The pure action selector, integer bearing and shared-canvas functions are AST-identical to their historical implementations. Their original verification modules are not imported or executed. Bearing fixtures are recalculated values, not a new native replay. Existing12-unit display height, anchor/crop and other authored presentation settings remain unchanged; the shared canvas is282×158. Native timing/AI/rendering parity is not claimed.

Isolated generation used a committed-tool snapshot plus this command, with legacy RE access disabled; no native/RE modules loaded. Four refusal controls covered existing output, absent originals, input overlap and incorrect texture. Legacy writers and evidence remain unchanged. Whole clean assembly and gameplay acceptance remain separate gates.
