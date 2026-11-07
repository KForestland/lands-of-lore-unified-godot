# River deck preparation

```sh
python3 tools/prepare_river_deck_media.py --game /path/to/original-game --output-root /path/to/fresh-output
```

Requires Python3, Pillow, published material/prop readers and docs/game-geometry-profiles.json. Original L1_DC is pinned. Output must be absent and cannot overlap the game. Fresh material export and all computation finish before output creation; no historical generated input, RE checkout, executable or native replay is required.

The command replaces the preparation roles of catalogue_river_deck.py, export_river_chains.py and export_river_regions.py, preserving their output layout. All33 files under assets/lol2/river_deck independently match the existing pack byte for byte: six deck records/material86,24 chain supports,27 chain frames plus the two earlier frame-zero preview names, and37 Rapids regions. The preview aliases are regenerated from the same original frames.

Independent checks compare regions and supports against fresh published geometry/prop exporters. Reader functions match their historical implementations; the height calculation agrees across256 flag values,55 floor/ceiling pairs and5 heights. Isolated generation loaded no native/RE modules. Four independent refusals cover existing output, overlap, missing originals and wrong archive. Contributor evidence also supplies11 controls, repeat generation and write-target tracing.

Legacy writers and docs/river-deck.md remain unchanged. Existing authored box UVs, billboarding, animation rate and liquid presentation are preserved. This preparation result does not establish native collapse timing or close whole clean assembly/gameplay/platform acceptance.
