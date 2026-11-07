# Hive Reaver and Amber media preparation

From the source checkout:

```sh
python3 tools/prepare_hive_reaver_amber_media.py \
  --game /path/to/original-game \
  --amber-source scripts/lol2/hive_reaver_amber_source.json \
  --pillars-source scripts/lol2/hive_reaver_pillars_source.json \
  --output-root /path/to/fresh-output
```

Use a new output directory separate from inputs. Python 3, Pillow and the published map-material, prop and item-icon helpers are required. No external RE checkout, native replay or historical generated exports are inputs. Use ordinary Python without optimization because checks include assertions.

The two existing published contracts supply seven control-material selections, item definitions17/112 and the pillar-image hash. The command pins the contracts and original Hive/GLOBAL/LOCAL archives, checks item names, identities and handlers, then regenerates materials, props and icons in a temporary directory. The first prop59 frame must match the published pillar hash. No new recipe is needed.

Only after all selected images exist and the checks pass does it create `assets/lol2/generated/hive_reaver_amber` under the requested output and copy its ten PNGs. Temporary exports are removed on exit. An output-copy failure may leave partial final output; preserve it and retry in a fresh directory. Keep generated media local. Both historical contract producers remain byte-identical and retain their existing CLIs.

Independent reconstruction reproduced all ten runtime images byte-for-byte, with no native or RE imports. Existing output, missing game and wrong-contract controls passed. This prepares the current media pack; it does not regenerate control geometry/event contracts or establish additional native behavior. R18 and gameplay remain unchanged, and complete Act1 assembly/acceptance remain separate.
