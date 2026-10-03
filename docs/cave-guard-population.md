# Cave guards — live encounter slice (2026-10-03)

Eight L1_DC placements (GGUARD 1, 2, 38, 39, 52, 53, 54; GGCAPT 56) run on the generic scripted creature owner (`scripted_creature_population.gd` / `scripted_creature_state.gd`), saved in cave saves as `guards` and validated by `walkthrough_save.gd`. The Museum skeletons now use the same owner through thin wrappers.

## Source-bound

- Presence: placement flag 0x1000 means the actor is not linked into the world until an `op9 … property3` command, whose native handler (B50C0 operation3 → B49EC(obj,1)) clears that flag and links the object. Only guard 52 starts present; the others are absent.
- Region groups (decoded from stream0 owners): 631 spawns 39 (one-shot via local4); 769/772/775 wake 39 (property13/7, no effect while absent); 1104 wakes 52; 1941 spawns 38; 106/121 spawn 53; 969 spawns 54; 23 spawns 1 and 2. Region history is saved once per region.
- Art: 981 original indexed frames (`tools/prepare_cave_guard_sprites.py`, shared preparer), 16-view walk, action9 appear/rise, action5 strike (100 % at frame 6/7), death, corpse. Native stat banks give fresh base 15 (`tools/prepare_cave_guard_population.py`). Reward scales: GGUARD 3, GGCAPT 5.

## Adapters

Shared playable damage (request × 0.4 = 6 per strike) and 0.8 s recovery; room-scale perception 600 with line of sight; speed 48; 8 fps clocks; pixel scale 0.25 (human height); spawned actors appear through their action9 clip then fight unless a later wake command is scripted. Control-driven sequences (controls 109/114/119/120, prop152/533 events, captain 56) and item grants are not live; the captain therefore stays absent.

## Checks

`cave_guard_population_state_test`, `cave_guard_live_test` (actual cave scene: source presence, region1104 wake, rise and hits, disk rollback, production melee XP into cave fighting state, region1941 spawn, defeat). Earned cave route rerun pending at time of writing.
