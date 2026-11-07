# Cave Roach disposition (2026-10-28)

Owner 2026-10-28: "the roaches are a lot in the Cave, scurrying around, and most are not hostile actually."
Evidence: `AI_COMMS/act1_completion_20261017/ROACH_BEHAVIOUR_DECODE_20261028.md` (§5) and its evidence folder.

## Native rule (proven)

- Every decision (AA208) scores the goal from a temporary bank: the persistent stats, plus the current goal's
  `globalai.csv` row, plus the Roach `effector.csv` row 9+c of every true condition c.
- Conditions 19/20/21 hold while the Roach perceives the player and player byte +0x1AB (Luther's form) is
  2 lizard / 0 human / 1 beast.
  - Lizard adds Aggressiveness +127 and Attacked +127, so the Roach picks **Destroy**.
  - Human and beast subtract 100/127, so it picks **Wander**.
- A landed player hit sets "Attacked by player before" to 255 (0xA724F). The slow update lowers it by 1 per game
  second (0xAB5F7). Facing a human or beast Luther, the Roach still wanders.

## Owner direction 2026-10-29 (r4)

the owner, about 10:00Z: "The roaches are walking around and scared of the player, if they attack the lizard that is ok.
Make a decision that makes sense and make it work as you see fit."

- The r2 override that skipped the native lizard row is removed. A perceiving Roach chooses **Destroy** against a
  lizard Luther (native row 19) and attacks on sight. It chooses **Wander** against a human or beast, also after
  being hit (native rows 20/21).
- "Scared of the player" is built into the scurry adapter. The native Wander movement is untraced. A wandering Roach
  that perceives the player picks its legs heading away from him. See DEVIATIONS 2026-10-29.

## Port

- `scripts/lol2/cave_roach_ai_source.json`: the original tables. They are staged by
  `python3 tools/prepare_cave_roach_ai.py --game ROOT` (deterministic; refuses an unsupported GLOBAL.MIX) and are
  equal to the native-recorded test contracts.
- `cave_roach_population_state.gd`:
  - `effective_bank` / `dispose` bind the health band, condition 45, condition 0 (last creature the player hit) and
    the form condition;
  - `advance_disposed` runs the existing pursue/bite adapter only for Destroy/Get player;
  - `player_hit` / `advance_ai` handle Attacked 255 and its decay;
  - the `ai` packet `{last_hit, clock}` is optional in saves.
- `cave_roach_population.gd`:
  - Flee moves away from the player;
  - other goals use the scurry adapter (`State.wander_leg`): short random legs and pauses, seeded per actor, a 160-unit
    leash around the spawn, never off a ledge; while the Roach perceives the player its legs head away from him.
- Adapters (DEVIATIONS 2026-10-28):
  - perception stays the 180-unit + sight adapter;
  - action-0 movement (scurry) is untraced;
  - conditions other than those bound above are not evaluated;
  - the entrance ROACH 23 and the wild actor 0 keep their own adapters.
- Test: `tests/cave_roach_disposition_test.gd` (headless). It fails on the old chase rule.

## Clock and restore review fixes

The attack-history clock preserves its fractional elapsed time across updates; rounding every frame to 1/1024 caused different decay rates at different physics frequencies. A 1e-9 boundary tolerance corrects floating-point error only when crossing an exact second. Transient scurry legs are cleared on restore so loading an older save cannot retain movement progress from the abandoned state. `cave_roach_clock_restore_test` compares ten seconds in one step with 30/60/120/240 Hz updates, with and without a mid-clock JSON round trip, and exercises the actual controller restore method with a minimal host. It fails on db57a4b and passes with these fixes. This is headless state qualification; rendered movement and fresh-process gameplay remain separate.
