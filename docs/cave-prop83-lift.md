# Cave prop83 chain: Mana foil shaft lift and wall opening

`tools/prepare_cave_prop83_lift.py` pins the chain. It writes `scripts/lol2/cave_prop83_lift_source.json` and stages sound request 956 as `assets/lol2/generated/cave_prop83_lift/956.wav` (local original media, 0.557 s).

## Source

**Prop83** (template92) is at (387, −192, −11066) in region1040, with placement durability 2.

1. **Hits.** Either kind9 record admits a hit at owner state0. Both are mode4 with threshold9; durability 2 already meets that.
   - **g108:** masks 0x0906/0x0004, i.e. melee.
   - **g124:** masks 0x0011/0x0001, i.e. Spark. It also writes local25 = 1.
   - Both play sound request 956.
2. **Sound finished.** A kind8 record with value956 fires when that sound ends (AE510), running g146:
   - selector2, state1;
   - other op9/op204/op21/op6 effects;
   - an op18 whose flags word 0x0805 lacks bit 0x20, so it queues nothing.
3. **Selector2 reached.** kind3 value2 runs g264:
   - op9 self property16;
   - op196 lifts the floors of shaft regions 397/434/436/451/452/503/505/506 from −1000 to −290 (absolute, speed5);
   - op196 drops the floors of regions 1029..1033 by 160 (relative, speed0, so immediately). These are solid zero-height wall regions (floor = ceiling = −32), so this opens the five wall regions into a 160-unit alcove beside regions 1037..1041. A strict shared-edge check shows the main chamber 1020..1028/1815..1819 stays sealed by its source edge slopes, while corridor 1820..1822 connects through region1033; see `cave-side-chamber.md`.
4. **Result.** The raised shaft floor sits a 5-unit step below the −285 rim.

## Port

- **State:** `cave_prop83_lift_state.gd` holds state, local25, the sound remainder, the shaft height and opened, saved by the cave host as `prop83_lift`.
  - `walkthrough_save.gd` validates it.
  - Sound time is consumed first. Only the remainder after the kind8 transition lifts the shaft, so one large step equals split steps.
- **Live owner:** `cave_prop83_lift.gd`.
  - **Melee:** an armed left click aimed at prop83 in reach. The host's left-click branch tries prop83 before the roach strike.
  - **Spark:** a ray that hits prop83's layer-2 collider; `player_starting_magic.gd` gains a generic `spark_receiver` meta.
  - **Sound:** the staged clip plays.
  - **Shaft:** prisms over the eight source floor polygons with convex collision. A player standing on one is carried.
  - **control75:** the box and the Mana foil marker ride the region506 floor (`cave_stone_manafoil.gd` `set_lift`).
  - **Opening:** removes the solid block's vertical faces in −192..−32, from host meshes and host collision, and adds a floor at −192 plus walls on its no-neighbour edges.
  - **Loading an older save:** the replaced meshes and shapes are kept. Loading a save from before the chain restores them.
- **Prop83:** stays in the world. g146's op5 selector2 switches it to template92 selector2, descriptor897 (the dripping-stalactite art family, staged by `tools/prepare_cave_stalactites.py`); g264's op9 property16 is B5401→E416C(23C68, prop, 1), which only stops prop83's own sounds (it does not hide or hand anything). Prop83 is not in the recovered prop preview, so the owner draws it.
- **g146 op9 property2 on props190/473:** B49EC(obj, 0) unlinks both from the world. Prop190 is hidden in the static preview; prop473 (an animated rock column beside prop83, omitted from the recovered pack) is drawn by this owner until then. Loading a pre-chain save restores both.
- **g146 op9 property21 → event20 (prop83 groups 460/478/490/508):** with local25 (0 = melee, 1 = Spark) and local11 (shared with the scenic guard's effects packet): the first solve raises the matching level by one (op2 sub0x0F fighting D7CEE / sub0x10 magic D88CD: award thresholds[level] − experience), later ones award 50 (sub9 → D8A1C, sub0x0A → D8B94). Applied once, live, at the chain transition.
- **Rendering:** the cave's final image is its layer-2 index viewport (`indexed_cave_wall_review` index camera, mask 2), resolved through the cave palette; the player camera's mask is 0.
  - Every mesh this owner adds is on layer 2 with the cave's indexed ShaderMaterial (`host._indexed_material`): each shaft floor's own `surface_indices/floor_<material>.png` on the prism tops, `wall_indices/material_134.png` rock on the sides and passage walls, and region1037's floor on the passage floor.
  - These meshes are mirrored into the cave's layer-4 mask pass (`host._copy_occluders`), and the mirrors follow moves and visibility.
  - Each shaft prism is built once at its final extent and slides vertically.
  - Prop83 is an indexed billboard quad (`sprite` mode) from its 8 exported index frames at 10 frames/s.
- **World gate:** the owner advances only while `player_starting_magic.world_active()` holds (inventory, cursor, death, movies, other scenes, pause, flying).
  - Sound 956 pauses and resumes with the world.
  - A mid-sound load resumes the clip at its saved remainder.

## Adapters and limits

- **Producers:** melee context 2/4 and Spark 1/1. kind8 fires at the staged clip's sample length.
- **Speed:** op196 speed = byte7 × 2.5 units/s, which assumes [0x22C54] counts 16.16 ticks at 60/s. The shaft takes about 57 s.
- **Riding objects:** objects on the shaft floor ride with it, as the Hive lift does with its control.
- **Not hosted:**
  - op9 property8 on prop83 (not decoded);
  - op204 materials and op6 event1 to prop614 (op21, the FLOOD movie, is hosted since 2026-10-28: `cave-cfall.md`);
  - g86 (an E use that writes local29 and plays a sound);
  - the sealed chamber's own props and interactions.

## Visual evidence

`opus/cave_stone_manafoil_20261009/lift_visual/` holds the probe that captured these, with native feet and shaft heights in its log:
- Grounded rim views before, mid-lift and raised, with feet −279.3 on the −285 rim floor.
- Diagnostic top-down views of the shaft at −1000, −650 and −290.
- prop83 and the opened passage.

## Tests

**`tests/cave_prop83_lift_state_test.gd`:**
- At the exact sound boundary the chain opens with no lift.
- Only the remainder lifts.
- One large step equals split steps.
- The top clamps, and invalid states are rejected.

**`tests/cave_prop83_lift_live_test.gd`** (actual Cave host, host walk step with `move_and_slide`):
- **Approach:** a 30-region grounded route from the rim (region398) to prop83. The walker hops (Space) when it stalls on small source floor lips.
- **Strike:** an unarmed strike is refused; an armed left click starts sound 956.
- **Chain:** state1, the wall ray clears, and prop83 is hidden.
- **Pause and sound:**
  - A mid-sound save and load resumes the clip at its remainder.
  - An open inventory, then a released cursor, freeze the sound remainder and pause the stream. Resuming advances exactly by the next step.
  - A paused lift holds its height and resumes without a jump.
- **Saves:**
  - A mid-lift save and load round-trips.
  - Loading the pre-chain save restores the solid wall, the unlifted shaft and prop83.
  - Reloading the mid-lift save reopens it.
- **Shaft:** walk back, step onto the raised shaft floor, take the Mana foil, and walk out to the rim.
- **Riding:** from the shaft bottom up and out.
- **Save validation** negatives.

Lead review reproduced and fixed a solid invisible prop83 collider after removal. Prop83 now stays visible (selector2), but its collider stays disabled after the chain: native prop collision is unproven, and the existing route through region1040 is kept. `cave_prop83_collision_rewind_test` verifies real physics-ray contact before activation, no contact after removal, and restored contact on rewind.
