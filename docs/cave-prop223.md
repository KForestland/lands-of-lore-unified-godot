# Cave prop223: the guard-pit explosion after the region-969 sighting

`tools/prepare_cave_prop223.py --scenic-source scripts/lol2/cave_scenic_guard_source.json --output scripts/lol2/cave_prop223_source.json` pins prop223's records and groups 2326/2732 from the original `L1_DC` archive. It asserts their exact relation to prop574's groups 5926/6364 and to the region-969 group 560, and it refuses to overwrite. `cave_scenic_guard_state.gd` merges the groups into the scenic group table.

## Source

**Prop 223** is a template-68 helper at (−261, −270, −15192) in region 53.
- Selector 0 is descriptor 615, the external `explode.vqa`; selector 1 (prop_617) is the fallback. Prop 574 uses the same template, so both play the same EXPLODE movie at their own position.
- Placement flags are 0x5402, durability 3. Bit 0x1000 marks the prop absent; link (B49EC with argument 1) clears it.

**Group 560** (region 969, predicate local0 == 0), already hosted:
- unlinks guard 55 and prop 574;
- links prop 223;
- spawns guard 54;
- sets property 17 on the fire props.

**Hit (kind9 `0a091609110000000283`, predicate 2 = owner state 0)**
- Masks 0x0011/0x0000, threshold 2, mode 0x83.
- In AE2C8's mode table (0x55290), mode 3 admits when before (+0x22) > 2 ≥ after (+0x26).
- Bit 0x80 then clears the record's mode, and mode 0 never admits, so the record fires **once**.
- The prop hit entry B4218 fills before/after through vtable 88 and 62728, writes the delta through vtable 84 (B71EC clamps durability at 0), then calls B4298 (flag 0x400 gate) and AE2C8.
- Both a tar fire hit (op19: masks 0x0010/0x0000, damage 5) and a Spark on 3 HP cross the threshold.

**Group 2326** = group 5926 with these differences:
- **First command:** op15 effect 101 spawns at prop 223 itself; prop 574's spawns at prop 222.
- **No reward:** no op9 property 21 on prop 1031, so no magic reward.
- **One sound:** no second op20 (sound 426); only sound 411 on prop 581.
- **Guard 55 untouched:** no actor55 op13 commands.
- **Added:** op6 sub-op 1 and op8 0/2 on prop 223 (load and play its movie).
- It also sets every fire's selector 2, property 17/19 and local0 = 1.

**Group 2732** (prop 223 kind6 value 0, its movie end): op8 1, op6 2, op16 state 1, op9 property 2 (unlink).

**Absent delivery (native, static):**
- Commands queue through 646EC → 662C4 → B6D34. B6D34 refuses only flag 0x800000, which the destroy routine B6B98 and the item constructor set; neither placement absence nor B49EC unlink sets it.
- The prop update B286C drains the queue (B58FC) **before** its absent test. The hit path tests flag 0x400 only.
- So a tar fire hit reaches prop 223 while it is still absent, and group 2326 runs.
- After the drain, an absent prop isn't updated further, so its movie never advances and group 2732 never runs.
- The group sets local0 = 1, which then blocks group 560: guard 55 and prop 574 stay, and guard 54 never spawns.

**Exclusivity:** prop 574's explosion (5926) also sets local0 = 1. Either way, the region-969 branch can no longer happen afterwards.

## Port

- **State:** `cave_scenic_guard_state.gd` adds `prop223_state` (optional in older saves; defaults to 0).
  - Events: `prop223_hit` → 2326 (requires prop223 state 0; prop223 doesn't need to be present), and `prop223_event0` → 2732 (requires prop223 present).
  - prop223's op16 and its op9 property 2 are applied internally.
  - The `seen` history keeps the record one-shot.
- **Effects:** `cave_scenic_guard_effects.gd` holds `prop223 {durability, movie_time, movie_loaded, movie_done}` (optional in older saves).
  - `receive_prop223_hit(mask0, mask2, damage)` replays the admission.
  - The movie clock runs only while prop223 is linked. The explode.vqa overlay is anchored at prop 223 while its movie plays.
  - op6/op8 on prop 223 are handled; the fire meshes and sound 411 reuse the existing prop-574 paths, so nothing is drawn or played twice.
  - A Spark box (the same 255 × 159 × 8 rule as prop 574) is active while prop223 is linked, at state 0 and not yet exploded.
- **Scenic guard:** `cave_scenic_guard.gd` routes `receive_damage("prop223")` (Spark) and `receive_prop223_hit` (source op19).
- **Tar:** `cave_tar_fires.gd` delivers each op19 on prop 223 with its source masks and damage (byte 8 when byte 9 is 0). `prop223_hits` remains a diagnostic count.

## Adapters and limits

- **Durability:** the clamp at 0 follows B71EC. Spark damage is the existing minimum-2 adapter.
- **Movie:** the 6 s / 15 fps movie clock is the existing prop-574 adapter. Completion of the absent-prop movie never happening is inferred from B286C's update order; it is not replayed.
- **Burst:** op15 effect 101 has no separate presentation; it shares the movie overlay, as for prop 574.
- **Static evidence only:** the native admission/queue facts are read from the code, not executed in a harness.
- **Not hosted:** the consumer of the property-17 flag (0x4000).
