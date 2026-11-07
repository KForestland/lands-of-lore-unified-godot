# Classic interface pieces: inventory panel and ring animations

The original inventory grid, equipment slots, stat icons and the Attack and Magic ring animations come from the same `intrface.shp` used by the classic HUD. Prepare them into a fresh root and merge `assets/lol2/generated/classic_interface` into the assembly:

```sh
python3 tools/prepare_classic_interface_media.py --game /path/to/original/game --output-root /path/to/fresh/classic-interface
```

**Inputs and checks:**

- **Originals:** `GLOBAL.MIX` `intrface.shp` (key 606080735, SHA-256 `1c03f2a0…`) and the `LOCAL.MIX` base palette (key 1915865337, SHA-256 `520c6fe3…`). These are the same pins as `prepare_classic_hud.py`.
- **Decoder:** the published `prepare_museum_interface.shape`, writing palette PNGs with index 0 transparent.
- **Checks before writing:** every shape is decoded and size-checked, and every PNG passes an index round-trip.
- **Output root:** it must not exist and must not overlap the game directory.

**Output:** 33 shape PNGs plus `manifest.json`, with roles listed in the tool's `ROLES` table:

| Shapes | Role |
|---|---|
| 78 | red inventory cell |
| 86 | grey equipment slot |
| 87–92 | slot silhouettes |
| 93–96 | gem tabs |
| 111–116 | stat icons: shield, fist, sword, bow, sword and shield, spell |
| 122 | stat bar |
| 57, 59 | health and mana fills |
| 132–137 | Magic ring cast animation |
| 138–143 | Attack ring strike animation |

**Roles are visual identifications:** they were matched against the original longplay (inventory open at 28:30, ring splash at 22:30), not taken from native code.

**Consumers:**

- `scripts/lol2/museum_inventory.gd` uses the original-style grid, stats and slots.
- `scripts/lol2/attack_swing.gd` uses the ring animations.

**Fallback without the pack:** both keep working. The inventory falls back to flat colours, and the rings play no animation.
