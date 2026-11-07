# Museum rubble-room blocks

```sh
python3 tools/prepare_museum_rubble_blocks.py --game /path/to/original/game \
  --materials /path/to/fresh/museum/materials --re-root /path/to/published_re --out /path/to/fresh-output
```

Copy the output to `assets/lol2/generated/museum_rubble_blocks`.

The rocky room behind the control96 wall (L3_DH regions 329–335, x 417–529, z −1272…−1401) holds fourteen original static-assembly boxes, plus block179 owned by control96. Placements 68–75 (owner report 2026-10-20 "stone cubes lying around") are ordinary active placements with the same flags as 64–67; block69 lies just west of the control96 wall (x 396–414). Owner witness, 2026-10-20 (original game in DOSBox): `~/lol2_original_screens/museum_20261020/orig_12-14-31.png` and `orig_12-14-45.png`.

| Placement | Template | Source x,y,height | Note |
|---|---|---|---|
| 64 | 34 | 452,1388,9 | stacked on 66 |
| 65 | 0 | 432,1390,−1 | block179 sits on it |
| 66 | 51 | 452,1390,−1 | |
| 67 | 51 | 485,1353,−1 | |
| 68 | 51 | 514,1313,−1 | |
| 69 | 34 | 405,1284,−1 | west of the control96 wall |
| 70 | 34 | 508,1363,−1 | |
| 71 | 34 | 460,1290,−1 | |
| 72 | 34 | 496,1296,−1 | |
| 73 | 0 | 467,1276,−1 | |
| 74 | 0 | 446,1277,−1 | |
| 75 | 0 | 501,1332,−1 | |
| 76 | 0 | 481,1384,−1 | |
| 95 | 51 | 433,1401,5 | region1010; plugs the low niche holding the Lightning crystal (item row7); placement flags 0x6982 differ from the others (0x2982), meaning unproven |
| 179 | 0 | 432,1389,11 | owned by control96; linked when its sequence reaches stage 1 |

The producer runs the published static-assembly exporter. It pins the 84 selected faces and their four material images (227, 236, 259, 319). It refuses existing or overlapping output, and it refuses state-dependent children for these placements. `scripts/lol2/museum_rubble_blocks.gd` draws the faces unshaded with nearest filtering, the same way as the gallery portraits.

Limits: the original data has no use record for these placements, so there is no motion, pickup, stacking or interaction. Collision is not added: whether static assemblies block the player has not been proven from native data. The room's lighting in the original is much darker than ours; that is a separate issue.
