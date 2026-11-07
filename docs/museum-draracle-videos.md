# Museum arrival and Draracle pedestal videos (2026-10-19)

Owner report 11:08 (R19): "should be starting the game the other way; should be able to go back to Draracle to see the other 2 videos and then barred".

## Source (L3_DH, LOLG.DAT)

- **Arrival.** Cave → Museum arrival index1 (selector1, region1226) is (-3796, -369) with heading 49152. With the port rule `yaw = -heading·TAU/65536` (Cave arrival, Hive rune and magic-shop return poses) the player faces +PI/2 (native −X). The port used a diagnostic −PI/2, which is exactly reversed.
- **Region1220** is the floor between the four template1 columns 132–135, just east of the arrival. Its event2 (grounded entry) records:
  - `080cce05c4040200` → g1486 under predicate48 (`local19 == 0`): `150387001800` op21 movie 24, `c60000001301` local19 = 1, `1201000059f173010000050800c0000a0000` op18 player → (-3751, -371) heading 49152;
  - `080cf205c4040200` → g1522 under predicate49 (`local19 == 1`): op21 movie 25, local19 = 2, op18 → (-3753, -373) heading 49152.
- **op21** (table 0x5C878 slot20 → B5AB5) calls CF2B4(byte4, byte5). CF2B4 indexes the movie-name table at ds+0xE568 and plays `"%s.vqa"` (names starting `ss-` are not movies). Entries 24 and 25 are `e032e` and `e033e`. `SPHERE1\L3_DH\E032E.VQA` and `E033E.VQA` are L3_DHI entries 5 and 6, the two clips the port had played automatically on arrival.
- These are the only two op21 commands in L3_DH, and no region event is attached to the arrival regions 1226 and 1228. Nothing natively plays these clips on arrival.

## Port behaviour

- Arrival yaw +PI/2 (`museum_review.gd reset_position`). The world is live immediately; nothing plays automatically.
- `museum_draracle.gd` and `museum_draracle_source.json` (from `tools/prepare_museum_draracle_videos.py`): on grounded entry into region1220, local19 0 plays e032e and local19 1 plays e033e (story overlay clips 4/5). Finishing or skipping a clip sets the next local19 and puts the player at the op18 return pose (arrival standing height, yaw +PI/2, pitch reset). A clip that ends any other way (interrupted or unavailable) keeps local19; the next entry plays it again. At local19 2 the pedestal does nothing.
- `start_introduction()` only starts while standing in region1220. Entry is edge-triggered and recomputed after loads and arrival, so loading inside the region does not count as an entry.
- Saved as `checkpoint.museum_draracle = {"local19": 0..2}` (optional; `museum_save.gd` rejects other shapes). Checkpoints and saves without the field come from the automatic introduction, so they restore as local19 2.

## Not hosted (reported)

- Control79 event4 at local19 2 (sound394, local19 3, then sound312 on event8 value394).
- "Then barred": region1174 g1364 (predicate45 `local17 == 0`, the hall east of the Draracle wing) closes bars 71–74 and gate77, plus music, props 136–139 and control82 events. The port does not render bar movables 71–74, so this needs its own movable owner.

## Checks

`museum_introduction_test` (registered, rendered): arrival pose and heading, no automatic clip, actual capsule walk east onto the pedestal (e032e), return pose, second walk (e033e, skipped), no third clip, checkpoint carry, interrupted clip retained, standing inside is not a new entry, save validation/legacy restoration. Negative control: the same test on the unpatched host fails at the arrival-heading assertion. `chamber_arrival_test` (unregistered) is updated to the new handoff.
