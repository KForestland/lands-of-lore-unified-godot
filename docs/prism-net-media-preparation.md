# Prism and Net of Exile media preparation

From the source checkout:

```sh
python3 tools/prepare_prism_net_media.py \
  --game /path/to/original-game \
  --museum-texture /path/to/L3_DH/materials/texture.bin \
  --hive-texture /path/to/L5_HC/materials/texture.bin \
  --contracts scripts/lol2 \
  --output-root /path/to/fresh-output
```

Supply the decoded textures from the fresh map-material pipeline. Python 3, Pillow and the published local prop, column and item-icon readers are required. No native audit or RE checkout is imported. Use ordinary Python without optimization because shared readers retain assertions.

The command pins both decoded textures and the three published Prism, Prism panorama and Net contracts. It stages Prism's original first display frame, its icon, all seven panorama panels, the Net pile sprite and its icon. Display hashes and each panorama payload hash are checked against the contracts. Item icons are decoded with explicit original-game input; the helper pins GLOBAL definitions and reads LOCAL graphics. The fixed display/definition selections preserve the existing preparers; no new native event or geometry proof is claimed.

Outputs are nine PNGs under `assets/lol2/generated/museum_prism` and two under `assets/lol2/generated/hive_net_exile`, plus intermediate decoded sprites under `tmp`. Keep all generated media local. Existing output roots, missing inputs, overlapping paths and mismatched pins are refused. A later decoding failure may leave partial output; preserve it and retry in a fresh directory. Historical source-audit preparers and published gameplay/geometry contracts are unchanged.

Independent full-pack reconstruction and this command both reproduced all eleven files byte-for-byte. Four controls (existing output, wrong texture, missing game and overlap) passed. The first private attempt covered only Prism display/icon; full-pack comparison caught the seven panorama files, and the failed attempt was preserved before completing the pack. Panorama images use the published column decoder with index-zero transparency. This work does not change R18 or establish full Act 1 assembly or content acceptance.
