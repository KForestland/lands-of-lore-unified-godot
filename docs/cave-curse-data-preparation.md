# Cave curse-region preparation

```sh
python3 tools/prepare_cave_curse_data.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This prepares the complete `assets/lol2/generated/cave_curse/regions.json` from pinned original `DAT/L1_DC.MIX`. It uses the published source/geometry readers, atlas sections, event-owner reader and command-group reader. No historical generated geometry or native replay report is an input.

The command discovers source region event 4 owners with predicate `0003010000` and the two commands `020100001324` and `c60000000101`. It extracts all five original owner records, command offsets, polygons and floor bounds, then checks the expected region/group pairs. Region 631/group 256 remains excluded, matching the existing runtime scope. Sorting by group preserves the historical pack order.

The output root must be absent and outside the game directory. All source checks run before writing. Lead verification reproduced the complete runtime JSON byte-for-byte with an isolated six-helper closure and no native/RE imports. Existing output, missing originals, overlapping output and wrong archive were refused without new output.

The legacy producer and its historical native replay evidence are unchanged. This command extracts source data; it does not replay random form selection, timing, collision or event execution.
