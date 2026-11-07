# Cave special-index sprite preparation

```sh
python3 tools/prepare_cave_special_media.py --game /path/to/original-game --texture /path/to/fresh/L1_DC/materials/texture.bin --output-root /path/to/fresh-output
```

Requires Python3, Pillow and published source/material/sprite readers. Prepare the texture using the published material exporter for L1_DC. Cave archive, texture and LOLG.DAT are hash-pinned. Output must be absent and cannot overlap inputs.

The command prepares both complete packs: special_cave_review (sprite474, remap and manifest) and special_prop_review (sprites474–476, remap and three-placement catalogue). All eight files independently match the existing outputs byte for byte. Original templates50–52 resolve to props1051/1057/1058 with identical bounds, positions, state/frame records and resource bindings.

The static fixup/parser and remap verification functions are AST-identical to verify_special_pixel_table_binding.py. They check seven LE relocations, pinned loader bytes and the texture's shade row64, retaining exact provenance. This reads original code bytes but performs no disassembly, replay or native execution. Later runtime remap changes, lighting, draw order and native rendering parity remain outside the result. Existing billboard/diagnostic conventions and historical scripts are unchanged.

Isolated generation loaded no native/RE modules. Five refusal controls covered existing output, missing originals, overlap, wrong texture and wrong executable. Decode failure may leave partial output; retain it for diagnosis and retry with a fresh directory. Whole clean assembly and final gameplay/platform acceptance remain separate gates.
