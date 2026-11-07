# Jungle–Hive route preparation

```sh
python3 tools/prepare_hive_routes_data.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This prepares the complete `assets/lol2/generated/hive_routes/routes.json` from original `DAT/L4_HJ.MIX` and `DAT/L5_HC.MIX`, with complete archive hashes checked. Published source/geometry, atlas, event-owner and command-group readers replace historical generated progression and arrival reports.

All four route pairs retain their existing order and runtime data format. Source region event owners must be unique, event 2, stream 0 and have no predicate. Each original level-change command must encode the expected destination level and entry. Destination arrival selectors must be unique; polygons, floor/ceiling bounds, command bytes and source offsets come from original records.

Arrival height preserves the existing authored convention: the highest support-region floor corner plus 34 units. Hive entry 1 has sloped support corners -10/-15; its review height is therefore 24. This is not native placement or crossed-region dispatcher evidence. Existing grounded admission and preserved-yaw behavior are unchanged.

Output must be absent and outside the game directory. Extraction checks precede writing. Lead verification reproduced the complete runtime JSON byte-for-byte with an isolated six-helper closure and no native/RE imports. Existing output, missing originals, overlapping output and each wrong archive were refused without new output. The legacy writer and historical native selector evidence remain unchanged.
