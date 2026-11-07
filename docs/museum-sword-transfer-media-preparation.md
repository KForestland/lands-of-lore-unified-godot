# Museum sword-transfer media preparation

```sh
python3 tools/prepare_museum_sword_transfer_media.py --game /path/to/original/game \
  --texture /path/to/fresh/L3_DH/materials/texture.bin --output-root /path/to/fresh-output
```

Requires Python/Pillow and the published prop, sprite and archive readers. Supply the fresh Museum texture produced by `lol2/map_materials.export_materials`; its complete decoded hash is checked. Original Museum/GLOBAL/LOCAL archives are pinned. No historical animation export or new recorded-data recipe is required.

The complete `assets/lol2/generated/museum_sword_transfer` pack contains70indexed skeleton PNGs, an RGBA sword and two JSON manifests. All73files match the existing runtime pack byte-for-byte in an isolated committed-helper run with no native replay imports. Existing-output, missing-game, altered-texture and overlapping-output refusal checks pass.

Original prop107 binds template39; its first views select bases1070/1082/1130/1383. Group counts12/6/21/31 and frame descriptors are read from the texture and decoded with the published block/LCW helpers. Item11 identity joins GLOBAL definition5 and inventory view276, decoded from LOCAL. Region1265 supplies the trigger polygon. The preparer retains the historical indexed-PNG transparency and sword index0/1 omission rules, including the exact rendering-scope manifest. Animation timing, attachment, camera-facing orientation and trigger behavior remain the existing authored runtime conventions; no new native parity is claimed.

The output must be absent and outside the inputs. Images are decoded before output creation; a later write failure may leave partial output, so retry in a new destination. The old historical staging script is untouched. Original files and generated media are excluded from source publication. Whole-project rendered qualification remains separate.
