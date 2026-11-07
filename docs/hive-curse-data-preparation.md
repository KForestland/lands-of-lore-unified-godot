# Hive curse-region preparation

```sh
python3 tools/prepare_hive_curse_data.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This prepares the complete `assets/lol2/generated/hive_curse/regions.json` from pinned original `DAT/L5_HC.MIX`. Published source/geometry readers, atlas sections, event owners and command groups are the only helper inputs. Historical replay reports and generated geometry are not preparation inputs.

The tool preserves the eight existing runtime admission regions and their order. Each region must have exactly one original owner with the expected stream, event 2, group and predicate. Polygons, base floor, corner bounds and complete command lists are read from original records. Predicates on regions 812 and 818 are checked as source bindings; the runtime data format is unchanged.

Output must be fresh and outside the game directory; all extraction checks precede writing. Lead verification reproduced the complete runtime JSON byte-for-byte with an isolated six-helper closure and no native/RE imports. Four controls refused existing output, overlapping output, missing originals and a wrong archive without creating new output.

The legacy writer, historical replay evidence and `tests/fixtures/hive_curse_lift_route.json` remain unchanged. This command does not regenerate that route fixture or establish new native timer, permission, admission or live command-execution evidence.
