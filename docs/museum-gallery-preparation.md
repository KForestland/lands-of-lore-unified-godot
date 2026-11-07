# Museum gallery preparation

```sh
python3 tools/prepare_museum_gallery_media.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This produces the complete `assets/lol2/generated/museum_gallery` pack (`gallery.json`, `painting.png`) from pinned original `DAT/L3_DH.MIX`. Published source/material/event readers, Pillow and `docs/game-geometry-profiles.json` are required. No historical generated input or constructor replay is used.

Movable placements 54/53/51 and templates 28/41/71 bind the painting, lever and grate. Original lever groups 12116/12140 and trigger bytes are checked against the source records. Fixed coordinates use the original coordinates shifted by 16 bits, matching historical constructor evidence. A fresh material export supplies painting resource 421; the archive, geometry, metadata and texture hashes are checked.

Output must be fresh and outside the game directory. Final files are written after source checks. Lead verification reproduced both files byte-for-byte with an isolated committed-source checkout and no native/RE imports. Original bindings agree with historical evidence, and four refusal controls cover existing output, overlapping output, missing originals and a wrong archive.

The legacy writer remains unchanged. The existing painting slide, backing plate, lever visibility/pose/colour, grate travel/timing and E interaction are authored runtime choices. Preparation does not newly verify native interaction acceptance or travel.
