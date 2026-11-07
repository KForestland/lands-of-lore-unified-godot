# Cave animated floors: lava, tar and water

the owner's 2026-10-14 playtest reported that "the tar pits should be bubbling and the lava is not filled in yet". The Cave indexed renderer drew every floor from its first frame, and the 86 lethal material135 lava regions (`docs/cave-lava.md`) used the purple unresolved placeholder.

Prepare the frames into a fresh root and merge `assets/lol2/generated/cave_animated_floors` into the assembly:

```sh
python3 tools/prepare_cave_animated_floors.py --texture /fresh/L1_DC/materials/texture.bin \
  --floors assets/lol2/generated/original_floors --surface assets/lol2/generated/surface_indices \
  --lava assets/lol2/generated/cave_lava --review /path/to/L1_DC/review.json --output-root /fresh/animated-floors
```

**Inputs and checks:**

- **Texture:** the L1_DC material cache (SHA-256 `102410e0…`, the same pin as `prepare_cave_surface_indices.py`).
- **Groups:** each base descriptor's word8 must be phase 0 with a group count, and every member must carry its own phase. The groups are: 135–144 lava (10 frames); 156–160 tar; 161–165 tar pool; 285–289 water (5 frames each).
- **Layout:** fixed by reproducing the shipped `surface_indices/floor_156.png`, `floor_161.png` and `floor_285.png` byte for byte from their phase-0 members. The same layout is applied to lava.
- **Lava UVs:** the shipped runtime floors have no UVs for the unresolved lava faces. They are taken from the recovered material135 review faces with the axes swapped. The swap is verified on all 1860 textured runtime floors first.
- **Output root:** it must be fresh and must not overlap any input. Existing-output, wrong-texture, overlapping-output and missing-input runs exit non-zero and write nothing.

**Runtime:**

- `indexed_complete_cave_review.gd` rebinds the material135 regions from `unresolved` to `lava_135`, with the lava UVs, through the new `original_walk_review._floor_source()` hook.
- The seven other unresolved floors keep the placeholder.
- `map_material_animation.gd` cycles the four groups.
- Without the pack, the Cave renders as before.
- Lethality (`cave_lava.gd`) and geometry are unchanged.

**Timing is a modern adapter:** 8 fps for lava and water, 5 fps for the tar materials. Natively, floor phases are stepped through timed records: `0x67460` selects a group member, and `0xB8AC4` draws a delay from a record range multiplied by word `0x223A8`, the same mechanism as `docs/hive-material-timers.json`. The Cave records have not been traced.

**Test:** `tests/cave_animated_floors_test.gd` (rendered). It checks that the lava rebinding is present, the placeholder is kept, the group sizes are 10/5/5/5, the lava frames step and loop, and a rendered view of pool 1471 shows lava colours with no magenta.

The `--review` input also accepts a fresh `review.json` produced by the published
`tools/lol2/map_surfaces.py` binder from original geometry/material exports. The
lava selector uses its `material` field when the optional visibility pass has not
added `visibility_original_material`. Both paths retain the same UV cross-check
against every already textured runtime floor. The fresh Cave binder reproduced
all 1,946 historical floor UV/material assignments exactly in the October 16
integration review. Native timing remains unverified.
