# Museum sludge floor (preset 17 "Sludge", resource 21)

The museum review pack textures a floor only when its resolved material is in the 2026-09-13 runtime capture set
(`scripts/lol2/museum_review_selection_source.json`). Resource 21 was never captured, so its 47 floors drew in the
review debug colour (magenta). Owner r3 report 2026-10-20 11:20:57 (Long arm chute) shows it.

Regions: Long arm pit 167–176, 204–220, 240; sludge chute 953–967; duct corridor 1368–1370, 1428–1463.

## Producer

```
python3 tools/prepare_museum_sludge_floor.py --game GAME \
    --review assets/lol2/generated/museum_review/museum.json --output-root FRESH
```

- Pins `DAT/L3_DH.MIX` and the rotation table.
- Decodes resource 21 with the published readers (`map_materials`): `raw_variant`, 10 variants, 128×128.
- Writes the frames in material 111's capture orientation (same `column_major_raw` family, transposed).
- Computes each sludge floor's UVs with the review's preset surface formula. Before writing any UV it checks that formula against all 1443 textured review floors.
- Refuses any unresolved floor whose resource is not 21 / "Sludge", and any count other than 47.
- Output: `assets/lol2/generated/museum_sludge_floor/` (`frame_0..9.png`, `manifest.json`). Gitignored like the other packs.

## Runtime

`scripts/lol2/museum_review.gd` (and so `museum_walkthrough.gd`) rebinds every `unresolved` floor listed in the
manifest to material key `21` with the manifest UVs, and animates the 10 frames through `surface_animation.gd`.
The museum.json pack and its pinned recipe are unchanged.

## Limits

- 8 fps is material 111's authored review rate, a modern adapter. The native phase clock is unverified.
- The frame orientation is inferred from material 111.

Test: `tests/museum_sludge_floor_test.gd` checks:
- every unresolved floor has a sludge UV;
- no material keeps the debug colour;
- the floor animates;
- the chute floor renders green with no magenta.

Captures: `captures/sludge/` (owner report before, chute after, longplay 26:50).
