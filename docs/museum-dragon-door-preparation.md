# Museum dragon-door preparation

```sh
python3 tools/prepare_museum_dragon_door_media.py --game /path/to/original/game --output-root /path/to/fresh/output
```

This produces the complete `assets/lol2/generated/museum_dragon_door` pack: `door.json` and `door.png`. It uses pinned original `DAT/L3_DH.MIX`, published source/material/event readers and `docs/game-geometry-profiles.json`. Pillow encodes the PNG. No historical generated inputs, constructor replay or executable are required.

Movable 82, template 30 and child 66 are extracted from original records. Fixed coordinates are the original coordinates shifted by 16 bits; historical constructor output is comparison evidence only. The original trigger and open-command group 12536 are checked. A fresh material export supplies texture resource 434, with the complete texture hash verified.

Output must be fresh and outside the game directory. Both files are written only after preparation checks pass. Lead verification reproduced both runtime files byte-for-byte using an isolated committed-source checkout with no native or RE imports. Placement, template and commands agree with historical source evidence; four independent refusal controls cover existing output, overlapping output, missing originals and a wrong archive.

The legacy writer remains unchanged. The existing authored E interaction and vertical 80-unit/one-second travel remain modern behavior; native motion and predicate acceptance are not newly verified.
