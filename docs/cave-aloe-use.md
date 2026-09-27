# Cave Aloe use

Cave Aloe (definition110, handler9) heals the player gradually. It is a pending heal of
+5 on player `22574+1A6` (global `2271A`). It does not write health directly. Mana is
unchanged.

**Execution proof** (`tools/verify_cave_aloe_use.py`, 36 use and 980 tick cases, results in
[cave-aloe-use.json](cave-aloe-use.json)):

- Only event1 is handled; other events return0 with no changes. Shared admission 7E968 is
  covered by `verify_player_item_effects.py`.
- When `269C4` bit0 is clear, the handler first calls presentation E3924 on `23C68` (not executed).
- 77ACC consumes the held item. If `223D4` is set, the item stays held. Even then, the +5 and
  `7C528(23819,0,30)` still happen and the handler returns1. Nothing checks for full health.
- Player tick D44F4 (with rate helper E1A60):
  - When pending is0, it snapshots the base byte `+163` from health. It skips this when
    `+227` bit5 is set.
  - It heals only when health≠0, pending≠0 and `+17D`=0.
  - Each tick's gain is `pending*30` times the 12-bit clock-fraction advance, divided by 4096.
  - Health above maximum `+149` clamps to the maximum and clears pending.
  - When health exceeds `base+pending`, base becomes `base+pending` and pending clears.
  - The tick then requests UI 7CADC(23819,health,max).
- Consequences:
  - Healing that is not clamped ends at least 1 above +5: 3→9 at 27 units per tick.
  - Large frame deltas overshoot until clamped, e.g. 3→30 in one tick of 1000 units.
  - Dead or paused players keep their pending heal.
  - Repeated uses stack.

**Static inference:** 7C528 sets object `23819` state byte to0 and a 16.16 timer to30,
with optional presentation 15C116. This reads as the use gesture. D44F4 is assumed to run
once per player update.

**Unknowns:**

- How long one 4096 clock unit lasts in real time.
- What 223D4, 17D and 227 bit5 mean.
- What E3924 and 15C116 present.
- The 9B8F0 and 5F830 release bodies.

Module `scripts/lol2/cave_aloe_effect.gd` implements this. Test:
`tests/cave_aloe_effect_test.gd` replays every fixture and checks the boundaries.

Publication scope: this detached planner and numeric fixtures are independently tested without original assets. The native replay tool remains in the local research checkout and is not included in this focused PR. Live inventory consumption, health-owner integration, saved pending healing and real-time pacing are not implemented by this publication. No original executable bytes, images, audio or personal saves are included.
