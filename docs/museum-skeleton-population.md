# Museum skeletons and Rat — live encounter slice (2026-10-03)

The thirteen L3_DH creature placements 20–32 (twelve `skel`, definitions 0/2, and Rat 22) are live in the Museum (`museum_skeleton_population.gd`), saved in the Museum checkpoint as `skeletons` (`museum_skeleton_population_state.gd`, validated by `museum_save.gd`).

## Source-bound

- Positions, headings, health (100/150, Rat 40), behaviour bytes, definition reward scales (def0 = 4, def2 = 2, Rat = 3) and placement loot identities (`tools/prepare_museum_skeleton_population.py`).
- Wake commands: region35 entry runs property13/7 on 24–26; region346 on 27/28/31/32; actors 24–26 wake each other when hit (event5 groups). Actors 20, 21, 30 are addressed by control92, prop107 and control96 handlers that are not yet live; 29 by region1057 (not yet live). These stay dormant until hit. Rat 22 and skeleton 23 have no wake command and use ordinary perception.
- Counter: each death of 23–32 runs `op207` = native `local[23] += 1` (dispatcher at 0x64770 decoded); predicate58 is `local23 == 10`; its handler runs `op210` sub-op 8 (audio level word = 0) and sets prop93 to state3. The live owner applies this after the tenth counted death. The check-versus-increment order inside one death was not executed natively.
- Clips from the original indexed frames (`tools/prepare_museum_creature_sprites.py`, 833 frames): idle, walk (8 views), rise (action9), three attack variants (action5: 50% at frame6; 100% at frame8/9; two 50% hits at frames6/11), death (action14), corpse (action15).
- Native attack base from `global\ai\skel\stat.csv` and `Rat\stat.csv`: total81 = 30, minimum82 = 3, fresh base15.

## Playable adapters (shared with Roach/DINO/Hive warriors)

Native hit amounts are requests that precede the unresolved damage calculation. Player-facing damage = request × 0.4 (`creature_live_rules.PLAYABLE_DAMAGE_SCALE`, the Hive warrior "base6" scale): 3 for 50%, 6 for 100%. 0.8 s recovery after each clip (Hive warrior adapter). Woken perception 600 with line of sight, reach 50, speed 48, 8 fps clocks, attack-variant rotation per clip, skeleton pixel scale 0.29 (opaque height ≈ human 46 units), Rat 0.218.

## Checks

- `museum_skeleton_population_state_test` and `museum_skeleton_live_test` (headless Museum scene; only the world gate replaced): dormancy, actual region35 wake, rise and pursuit across the room, hits, disk rollback, production melee XP, Spark, ten deaths → prop93 state3 persisted, retry.
- Earned Museum→Jungle walk (`museum_earned_walk_test.gd`) passes from the new earned cave save, defeating 27, 28, 31, 32, 29 and 20 with production strikes and spell-key healing; see `museum-earned-jungle-walk-checks.json`.

## Open

Loot drops (skeletons carry "92-Sk key"; 30 carries "68-SS1"; 32 carries "12-Tho Broken" and its event8 empties the sword case — the current earned case pickup is unchanged), prop93's visual/state3 consequence and its 12-item use handler, the control92/96 and region1057 triggers, music, sounds, rendered review and Bob's playtest.
