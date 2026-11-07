# Cave Aloe and stalagmite preparation

From the source checkout:

```sh
python3 tools/prepare_cave_harvest_packs.py \
  --game /path/to/original-game \
  --texture /path/to/fresh/L1_DC/materials/texture.bin \
  --output-root /path/to/fresh-output
```

The command requires Python 3, Pillow and the published local map-prop, event/command and item-icon readers. Supply the decoded texture from the fresh map-material pipeline. No external RE helper or native emulator is needed. Use ordinary Python without optimization because source checks include assertions.

The wrapper pins the Cave archive and decoded texture, builds eight palette-index sprite images and a temporary index manifest, then calls the unchanged Aloe and stalagmite producers with explicit paths. Those producers read the original template, placement, predicate and command records to rebuild both full manifests. It additionally decodes the Stalagmite inventory icon from original item definition0.

Outputs are five files under `assets/lol2/generated/cave_aloe` and eight under `assets/lol2/generated/cave_stalagmite`. Temporary map images remain under `tmp/cave_harvest_map`. Keep generated media local. The wrapper refuses existing output, missing inputs, overlapping paths and incorrect archive/texture pins. A later source or decoding failure can leave partial output; preserve it and retry with a new directory. The two lower-level historical producers retain their defaults and can overwrite their requested outputs; use the wrapper for fresh assembly.

The earlier pre-glow reconstruction with the RE fallback disabled reproduced all eleven files byte-for-byte, including both manifests. The wrapper reproduced the same complete packs and passed existing-output, wrong-texture, missing-game and overlap controls. This verifies original source records and existing output generation; it does not replay native scheduling or effects, change gameplay, or establish whole Act 1 acceptance. R18 is unchanged.

The crystal glow extension also writes `blend_upper.png` (256×128 original palette-index lookup bytes) and `blend_upper.json` (source, offset and output hashes). Original loader/plotter relocation evidence places this table at texture header offset0x1c +0x8000, corresponding to object4+0xc200. Fresh reconstruction reproduced all thirteen current files byte-for-byte. The current reference renderer uses unshaded source indices; original shade-row selection and full native rendering parity remain unimplemented. Generated-table reproduction does not establish rendered correctness.
