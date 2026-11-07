# Complete Hive attack-data preparation

```sh
python3 tools/lol2/map_materials.py export --game-root /path/to/original/game --area L5_HC --out /path/to/fresh/materials
python3 tools/prepare_hive_attack_data.py --game /path/to/original/game --texture /path/to/fresh/materials/texture.bin --output-root /path/to/fresh/output
```

The first command needs the published geometry profile. The second uses only three published source/material/creature readers and the standard library. Complete hashes pin `DAT/L5_HC.MIX`, `GLOBAL.MIX`, `LOLG.DAT` and the fresh Hive texture.

This prepares all 11 files in `assets/lol2/generated/hive_attack`: action and goal choices, effect-condition flags, marker bank and manifest, actor marker, attack adjustments, AI adjustments, initial stats, attack clips and animation clips. Original CSV fields supply weights/stat tables; original geometry supplies marker bytes and actor 36's initial marker; initialized LE executable pages supply the effect-flag window; metadata and texture descriptors supply animation counts, intervals, events and action labels.

The original definition supplies total 30. The historically replayed constructor minimum 3 is retained explicitly, with the original constructor code-span hash checked; this command does not replay that calculation. Historical native parser, animation, scoring, admission, marker-loader and constructor verifiers/fixtures remain unchanged. The source extraction makes no new live AI or timing claim.

Output must be absent and outside both inputs. All extraction checks and in-memory serialization precede final writes. Lead verification reproduced the complete 11-file runtime pack byte-for-byte with an isolated tool and three-reader closure. Seven refusal controls cover existing output, overlapping output, missing originals, wrong texture and each of the three wrong original files. Generated data, including original marker bytes, stays outside source publication.
