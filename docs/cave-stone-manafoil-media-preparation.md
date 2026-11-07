# Cave Stone and Manafoil media preparation

Run from the source checkout:

```sh
python3 tools/prepare_cave_stone_manafoil_media.py \
  --game /path/to/original-game \
  --materials /path/to/fresh/L1_DC/materials \
  --source scripts/lol2/cave_stone_manafoil_source.json \
  --output-root /path/to/fresh-output
```

Use the fresh map-material exporter output, including `texture.bin` and `material_0086/mip_0_palette.png`. Python 3, Pillow and the published prop/item-icon helpers are required; no RE checkout or native audit is imported. Run ordinary Python without optimization because source and shared decoder checks include assertions.

The command pins the source contract, Cave decoded texture and material86 PNG. It decodes descriptor477 as both colour and palette-index sprites, decodes the two item icons from explicit originals using the contract's item definitions, and retains the existing nearest-Cave-palette conversion for Manafoil's index image. The six images go under `assets/lol2/generated/cave_stone_manafoil`; intermediate sprite images remain under `tmp/cave_stone_manafoil`. Generated and original media remain local.

Existing output, missing inputs and overlapping paths are refused. Contract and material-image mismatches are checked before staging. A later decoding failure can leave partial output; preserve it and retry in a new directory. The historical source-audit preparer and its gameplay/assembly contract are unchanged. This command does not regenerate event ownership, box geometry or the modern selector adapter.

Independent extraction and the explicit command both reproduced all six runtime images byte-for-byte. Existing output, wrong source contract, missing game and overlapping output controls passed. This is media-preparation evidence only; it does not change R18 or establish whole Act 1 assembly or content acceptance.
