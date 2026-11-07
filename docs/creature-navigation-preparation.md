# Prepare Act 1 creature navigation

Use Python 3 and your original installation, including `LOLG.DAT` and the four area archives. No companion RE checkout, native emulation or third-party Python package is needed. Run from the source checkout with fresh map and output directories:

```sh
LOL2_GAME=/path/to/original/game
LOL2_MAPS=/path/to/fresh/maps
LOL2_STAGE=/path/to/fresh/navigation-stage
for area in L1_DC L3_DH L4_HJ L5_HC; do
  python3 -S tools/lol2/map_geometry.py --game-root "$LOL2_GAME" \
    --area "$area" --out "$LOL2_MAPS/$area/geometry" || exit 1
done
python3 -S tools/lol2/map_ceiling_subdivisions.py \
  --game-root "$LOL2_GAME" --geometry-root "$LOL2_MAPS" || exit 1
python3 -S tools/prepare_creature_nav.py \
  --maps "$LOL2_MAPS" --output-root "$LOL2_STAGE"
```

The existing geometry profiles pin the source archives. The ceiling-subdivision step checks the original executable hash and reuses the published local slope helpers. It updates only the fresh geometry directory. It is required before navigation preparation; do not substitute an unpatched geometry export.

The last command writes four JSON files under `assets/lol2/generated/creature_nav/`. It builds all four graphs before replacing any output. An invalid later input therefore leaves previous graphs unchanged. This does not promise atomic writes if the filesystem fails during output replacement. No-argument invocation retains the historical map path and repository output root; use explicit paths for clean preparation.

Independent regeneration from originals reproduced all four existing files byte for byte: L1_DC 1,954 regions/5,206 edges; L3_DH 1,499/2,488; L4_HJ 4,787/13,226; L5_HC 1,292/1,952. A deliberately broken final-map input was rejected without changing any existing graph. Geometry export and navigation preparation ran with `python3 -S` using only the local source dependency closure. The ceiling helper functions match their previously used versions without semantic changes.

These graphs retain the existing modern navigation rules: at least 47 units of standing clearance, at most 32 units of floor step, and portals at least 24 units wide. This work changes preparation paths, not navigation behavior. It does not claim native pathfinder parity or prepare the complete game asset tree.
