# Cave guards — live encounter slice (2026-10-03)

Eight L1_DC placements (GGUARD 1, 2, 38, 39, 52, 53, 54; GGCAPT 56) run on the generic scripted creature owner (`scripted_creature_population.gd` / `scripted_creature_state.gd`), saved in cave saves as `guards` and validated by `walkthrough_save.gd`. The Museum skeletons now use the same owner through thin wrappers.

## Source-bound

- Presence: placement flag 0x1000 means the actor is not linked into the world until an `op9 … property3` command, whose native handler (B50C0 operation3 → B49EC(obj,1)) clears that flag and links the object. Only guard 52 starts present; the others are absent.
- Region groups (decoded from stream0 owners): 631 spawns 39 (one-shot via local4); 769/772/775 start control109 (op16 state1) whose animation endpoint (event5, per Codex's control-endpoint lead) relinks guard 39 through prop533, whose endpoint spawns it, and property13/7 enable it — collapsed here to spawn+wake 39 on region entry (no door/prop animation); 1104 wakes 52; 1941 spawns 38; 106/121 spawn 53; 969 spawns 54; 23 spawns 1 and 2. Region history is saved once per region.
- Art: 981 original indexed frames (`tools/prepare_cave_guard_sprites.py`, shared preparer), 16-view walk, action9 appear/rise, action5 strike (100 % at frame 6/7), death, corpse. Native stat banks give fresh base 15 (`tools/prepare_cave_guard_population.py`). Reward scales: GGUARD 3, GGCAPT 5.

## Adapters

Shared playable damage (request × 0.4 = 6 per strike) and 0.8 s recovery; room-scale perception 600 with line of sight; speed 48; 8 fps clocks; pixel scale 0.25 (human height); spawned actors appear through their action9 clip then fight unless a later wake command is scripted. Control-driven sequences (controls 109/114/119/120, prop152/533 events, captain 56) and item grants are not live; the captain therefore stays absent.

## Checks

`cave_guard_population_state_test`, `cave_guard_live_test` (actual cave scene: source presence, region1104 wake, rise and hits, disk rollback, production melee XP into cave fighting state, region1941 spawn, defeat). Earned cave route rerun pending at time of writing.

Rendering: cave creatures use the cave composite (indexed surface shader, layer 2, occluder/light copies updated per frame), the same path as the Roach population. Rendered QA 2026-10-03 (tmp/visual_qa/cave_guard52.png) found the first guard build invisible in the cave composite; fixed by the `cave_indexed` render mode.

Navigation limit (2026-10-03): creatures pursue only with line of sight and have no pathfinding. Guard 39 now spawns and wakes when the earned route crosses region 775, but its source spawn point (-1051,-5871) is in a side room without a view of the route, so it waits there unless the player looks in (probe in session log). Pathing around walls/doors is an open adapter item for all creature populations.
