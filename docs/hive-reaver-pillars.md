# Reaver corridor pillars (alternative collapse triggers)

`tools/prepare_hive_reaver_pillars.py` pins four Hive props and their hit records byte for byte. It writes
`scripts/lol2/hive_reaver_pillars_source.json` (numbers only) and stages the original first frame as
`assets/lol2/generated/hive_reaver_amber/pillar.png`. That frame is local original media and is never published.

## Source (L5_HC stream 1)

Props 401, 426, 676 and 725 are cracked rock support pillars:

- template 1 or 5, material `prop_59`, 64×128 units;
- all in corridor region 366, floor −235.

Each pillar owns five kind9 records. kind9 is the prop hit event, as witnessed for the Museum hourglass.

| Value | Condition | Commands |
| --- | --- | --- |
| 2048 | pillar state 0 | op208 (2,2), sound 0x3BB, pillar state → 1 |
| 2048 | pillar state 1 | op208 (3,3), sound 0x3BC, pillar state → 2 |
| 2048 | pillar state 2 | op208 (3,2), sound 0x2B9 (state stays 2) |
| 2048 | always | sound 0x2BA, op196 region 365 floor → −234, speed 20 |
| 0 | always | sound 0x3BC |

The unconditional op196 is the same 1-unit nudge the Reaver timer makes (there at speed 5). It starts the existing
collapse chain ([Hive Reaver alcove](hive-reaver-amber.md)). So in the source data, hitting any pillar brings the
corridor ceiling down, even if the sword was never taken.

**op208 (sub 0, `0x65518`):** keeps the maximum intensity (byte 5) and duration (byte 6 × 60 ticks). This is read as a
timed screen shake. The reading is an inference; the consumer is not traced.

## Port

- **Pillars:** the four pillars are shown with their first original frame. Each has a hit-only body on layers 4|8.
  Melee rays (mask 7) and Hive Spark rays (mask 11) reach these bodies, but the player does not collide with them.
  The corridor stays walkable between the pillars.
- **Hits:** a landed player hit counts as a kind9 hit. That is either a melee strike through
  `hive_warriors.strike()` → `hive_hit_receiver`, or a Spark through `spark_receiver`. Each hit:
  - runs the pillar's state record (0→1, 1→2, 2 stays);
  - shows "The cracked pillar shudders.";
  - runs the region-365 nudge.

  A free cursor or pause refuses the hit.
- **No duplicates:** a request for a target that is already reached or already being approached changes nothing. So
  repeat hits, other pillars and the later Reaver timer never start a second chain.
- **Sword availability:**
  - A sword already taken is kept.
  - After a pillar starts the collapse, the sword can still be taken until the alcove seals, i.e. until region 364's
    floor and ceiling meet.
  - Once the alcove has sealed, the sword is lost: it cannot be targeted, and `take_reaver` refuses.
- **Saves:**
  - Pillar states are saved as `quests.hive_reaver_amber.pillars`.
  - Older saves without that field load with every pillar at 0.
  - Validation still rejects a collapse when neither the Reaver was taken nor a pillar was hit.

## Adapters / not hosted

- The kind9 value filter (2048 or 0, possibly a hit mask or a depleted threshold) is not traced. Every landed player
  melee or Spark hit runs the value-2048 records. The value-0 record (sound only) is not hosted.
- The op208 shakes and op20 sounds are not hosted. These presentation effects remain outside this implementation.
- The pillar is a static first frame: no frame animation and no visual change between states.
- The HUD line is modern text.

Test: `tests/hive_reaver_pillars_live_test.gd`, registered in `tools/run_regressions.py`. It covers:

- a real strike and a Spark hit;
- repeat hits without a duplicate chain;
- pause refusal;
- a pre-seal E take, then production grounded escape between the pillars;
- final heights, the timer no-op and a single Reaver;
- the sealed-alcove loss branch, with disk reloads;
- older saves and validation.

Independent review (2026-10-10): the numeric source contract and original pillar frame regenerate byte-identically. A live negative check reproduced missing sword-loss feedback: the sealed alcove cannot be targeted, so its interaction hint never explains the loss. The owner now announces the loss at the sealing transition when the sword is untaken. Added checks cover paused collapse, an untaken active-collapse disk checkpoint, and loss feedback. Combined10/10 Hive combat, escape, item, reward and save checks passed with unchanged source, including the merged Net/Prism hooks. The rendered pillar was inspected. This reviewed source is integrated after R12; it is not part of the R12 binary.
