# Museum Lightning crystal (item row7)

```sh
python3 tools/prepare_museum_lightning_crystal.py --game /path/to/original/game --output-root /path/to/fresh-output
```

Copy `assets/lol2/generated/museum_lightning_crystal` from the output root.

Owner report 2026-10-20 (r3 playtest): "there should be a storm crystal behind the block". The source agrees: L3_DH item row7 is GLOBAL definition55 `56a-Ltng cr` (identity 0x84D4248D, handler 8) at native (431,1416,5), flags 2 (active), region1010. It lies in a low niche under a slab at height 19, directly behind rubble block95 (x 424–442, height 5–16, z −1405…−1397).

The producer pins the three archives, the geometry, the row7 record and definition55, and decodes the definition's first-selector view resource (81, 19×13) the same way as the Jungle world items.

`scripts/lol2/museum_lightning_crystal.gd` places it as a billboard sprite with the shared museum reach test (`can_reach_item`, E). A standing human cannot see into the niche; small form can. Collected state rides on `carried_collected` like the Champion Stones; no new save field.

Not proven / not replayed: item handler 8 (what using it does), whether block95 must be moved first (its placement flags 0x6982 differ from the other blocks; blocks currently have no collision), and native pickup admission.
