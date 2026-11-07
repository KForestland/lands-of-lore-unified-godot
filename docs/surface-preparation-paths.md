# Portable surface-binding inputs

`tools/lol2/map_surfaces.py` uses the published `game-geometry-profiles.json`, local MIX readers and original `LOLG.DAT`. It no longer requires an unpublished source inventory, a companion RE import or a rotation table under a fixed local directory.

Given geometry and materials already exported beneath a maps root, bind an area into that same root:

```sh
python3 -S tools/lol2/map_surfaces.py \
  --game-root /path/to/original/game \
  --root /path/to/prepared/maps --area L1_DC
```

The geometry and materials remain prerequisites. This command updates the selected area's `review.json` and `surface_coverage.json`. Use a private maps root to preserve an existing review. It does not independently assemble scenery, movies or the complete game.

The published profile supplies the area name and pinned archive/geometry identities. Actor and prop counts are read from the pinned geometry's bounded placement tables. Their resulting values match the old source inventory for all fifteen areas; no quest/status metadata is needed by surface binding. Internal `source_tables` callers receive the geometry profile plus these counts, not the old inventory's unrelated quest/research fields.

## Rotation table

The table is generated in memory from two doubles in the supported `LOLG.DAT`, at file offsets 1852528 and 1852536 (LE initialized-object offsets 0x344c and 0x3454). The executable SHA-256 must be `b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775`. The 4,096 little-endian signed integers must hash to `d7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53`.

For another preparer that still needs a table file, produce a fresh one explicitly:

```sh
python3 -S tools/lol2_rotation_table.py \
  --game-root /path/to/original/game --out /path/to/fresh/rotation_table.bin
```

It refuses an existing output file, a changed executable or a table hash mismatch. The historical host-x87/libm comparison agreed at every entry; the portable generator retains the exact table hash rather than accepting platform-dependent differences. It does not claim equivalence to live guest floating-point state.

Private verification compared complete old/new bound outputs for Cave, Museum, Jungle and Hive using the same prepared geometry/material inputs: both output JSON files matched byte for byte in every area. The new process ran with `python3 -S` and an explicitly invalid external-helper root. All 16,384 rotation bytes matched the old table. Wrong-original and changed-math controls were refused. This verifies removal of preparation dependencies, not a new rendered runtime result or complete clean-media assembly.
