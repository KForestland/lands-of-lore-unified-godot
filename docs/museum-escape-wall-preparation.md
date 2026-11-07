# Museum escape-wall preparation

```sh
python3 tools/prepare_museum_escape_wall_media.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This produces the complete six-file `assets/lol2/generated/museum_escape_wall` pack from pinned original `DAT/L3_DH.MIX`: four stage PNGs, `wall.json` and `escape_regions.json`. It needs the published source/material/event readers, Pillow and `docs/game-geometry-profiles.json`. It needs no historical generated inputs or constructor replay.

Control 97, template 33, child state masks and resources 408–411 come from original records. A fresh material export provides the pinned texture container. The published column decoder replaces the legacy unpublished decoder; verification confirms identical pixels for resources 409–411. Original region event owners connect regions 716–718 to their hourglass disable/state-5 command groups; polygons and source offsets are extracted directly.

Output must be fresh and outside the game directory. Images are encoded in memory and final files are written after source checks. Lead verification reproduced all six runtime files byte-for-byte using an isolated committed-source checkout with no native/RE imports. Source bindings agree with historical evidence; four independent controls refused existing output, overlapping output, missing originals and a wrong archive.

Both legacy writers remain unchanged. The existing runtime plane, yaw, light shaft, reveal timing, sword damage, collision opening and region guards remain authored behavior. Preparation does not establish new native execution evidence.
