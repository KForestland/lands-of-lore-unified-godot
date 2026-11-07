# Museum gate preparation

```sh
python3 tools/prepare_museum_gate_media.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This prepares both files in `assets/lol2/generated/museum_gate` from pinned original `DAT/L3_DH.MIX`. It needs published source/material readers, Pillow and `docs/game-geometry-profiles.json`. It has no historical generated input, constructor replay or executable dependency.

Original movable 77 supplies template 58, position and angular mode. Its encoded angle yields 19660 units using the historically verified conversion. Template dimensions and child bounds establish width/height; resource 908 supplies the artwork through a fresh material export and the published column decoder. The original archive, geometry, metadata and texture hashes are checked.

Output must be fresh and outside the game directory. Final files are written after source checks. Lead verification reproduced both files byte-for-byte in an isolated committed-source checkout without native/RE imports. Original bindings and decoder pixels agree with historical evidence; four independent refusal controls cover existing output, overlapping output, missing originals and a wrong archive.

The legacy writer remains unchanged. The 121×199 artwork is stretched onto the existing 54×78 panel; the left hinge, negative yaw, 1.2-second motion, two-unit collision thickness and sword-sequence activation remain authored runtime conventions. This preparation does not newly verify native motion or collision.
