# Attached scenery preparation

Prepare type1 children of movable or static assemblies from the supported original installation:

```sh
python3 tools/export_map_attached_props.py --game-root /path/to/original/game \
  --re-root /path/to/repository --area L8_SJ --placement-kind static_assembly \
  --out /path/to/fresh-output
```

Use `movable` for the other placement table. The output contains `type1_props.json` and decoded sprite images. The output directory must be fresh and must not overlap the original game, helper repository or installed tools. The command sets the explicit helper root before importing the library. A later decoder failure can leave partial fresh output; retain that output for diagnosis.

The published helper closure and host requirements are those in [movable preparation](map-movables-preparation.md): RE revision `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c`, Capstone and Pillow. This exporter also uses `lol2_wall_material_checkpoint.sections`, already in that closure. `export_map_movables.py` supplies template and placement parsing. The rotation table is regenerated from the supplied original executable and checked against its pinned hash. No captured rotation-table file is required for area export. The lower-level `export_type1_records` API retains its historical default; callers can supply an explicit rotation table and executable.

Fresh exports were compared against the existing reports for L1_DC, L3_DH, L4_HJ, L5_HC and L8_SJ, with both placement kinds: all ten serialized reports and generated PNGs matched. L8_SJ contains 37 movable attached instances and 97 static attached instances. An explicit CLI extraction matched the latter report. Existing-output, missing-game, wrong-executable and overlapping-input controls rejected without modifying output.

This reproduces initial attached scenery and records hidden states and unresolved issues. It does not implement mechanism motion, collision, native runtime admission or the complete darker-Jungle arrival assembly. Type0 assembly faces use the separate movable exporter.
