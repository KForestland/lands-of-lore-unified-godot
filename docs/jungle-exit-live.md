Source-presence correction: prop552 has original absent flag0x1000 and is linked by region1921 pred119. The exit visibility owner now starts absent. Bacatta component will supply authoritative presence; current isolated visibility test explicitly supplies that prerequisite. Earlier default-present scene check was incomplete and is superseded.

Production integration update (2026-10-03): Jungle host now creates the encounter, validates and transports an optional quest packet, mirrors immediate melee damage before saving, and restores partial movies with movement/combat paused. The existing HUD handles F5/F9 during movies. Native F6C87 first eligible prop rendering is approximated by camera-frustum and world-occlusion samples at source prop552; saved seen/present flags preserve one-shot admission, and rejected predicates remain retryable. Source GLOBAL names13/14/18/47 are pinned by the preparer. Actor58–60 targets join Spark/aura; native melee reward scales1..255 are accepted, including these guards'10. Original frame/voice durations, not frame count alone, validate partial playback. See jungle-exit-integration-checks.json. The Bacatta branch is now integrated; see [jungle-bacatta.md](jungle-bacatta.md) for its source producers and validation scope.

# Huline Jungle exit encounter: live consumer (2026-10-03)

Isolated live controller for the staged source component in [jungle-exit-encounter.md](jungle-exit-encounter.md). It is not wired into `jungle_walkthrough.gd`, the save file or the regression runner yet. The guard spawn trigger is still supplied.

## Files

| File | Role |
| --- | --- |
| `scripts/lol2/jungle_exit_encounter.gd` | Live controller (Node3D). One saved packet: source state, generic guard packet, pose clocks, movie phase, region-entry history. |
| `scripts/lol2/jungle_exit_encounter_state.gd` | Source interpreter. Now has saved opcode8 cursors and stricter save validation (see below). |
| `tools/prepare_jungle_exit_guard_population.py` → `scripts/lol2/jungle_exit_guard_population_source.json` | Guards58–60 (GGuard def9) in the generic scripted-creature schema. 255 HP, absent at load, native GGUARD base15, attack selector3 hit at frame7 (100% → 15), reward byte +0x83 = 10. |
| `tools/prepare_jungle_exit_movies.py` → `assets/lol2/generated/jungle_exit_movies/` | Original media, local only (ignored, 63 MB). |
| `tests/jungle_exit_encounter_live_test.gd` | Focused test on the real Jungle scene host. |

## Source findings

- **Cutscene poses are VQA clips, not resource509.** Def9 selector8 → resource464 and selector12 → resource461 are texture type 0x342 descriptors. Each has a 22-byte payload: an 8-byte header and then a VQA name. 464 = `1790004E.VQA` (22 frames, 176×204), 461 = `1795004E.VQA` (26 frames, 120×196). Both are 15 fps with voice audio and are exact in `DAT/L4_HJI.MIX`. Selectors 9/10/11 = `1790304E`/`1790404E`/`0190504E`. Resource509 (selectors 14–18) is a 16×16 placeholder. Visual check: both clips are short in-place guard gestures (sword and shield moved, ending in guard stance) on a pure-blue key. They are not cinematic cutscenes.
- Ending movies: HW-BRDGE 91 frames, E068E 288, E069E 224 (640×400, 15 fps). Every VQFR frame and every SND2 sample is asserted.
- Predicate182 (spawn) has no one-shot latch. A repeated prop552 kind5 dispatch re-runs group10720 (local56=1, links). Guards are not duplicated. How often the native producer fires therefore matters.
- Region4435 itself removes prop552 (`090328020200`), and predicate182 does not depend on local42. This bears on the kind5 producer question: if the walker only visits linked objects, the spawn must happen before region4435.

## Opcode8

The interpreter used to run every command at once. Now each queued group keeps a saved cursor (`pending: [{group, cursor}]`). An opcode8 command passes only when the supplied `ctx.opcode8(command)` Callable returns true. Otherwise that group waits until `resume()`, and other queued groups keep running (the same adapter as `cave_scenic_guard_state.gd`). The validator accepts a cursor only if it points at an opcode8. Packets without `pending` are treated as having nothing waiting.

Controller policy (an adapter, not a native timing claim): opcode8 argument2 on a guard waits until that guard's pose clip ends. If the guard has no clip pose, there is nothing to wait for. All other opcode8 commands (arguments 0/1, prop552 0/7/10) pass at once. At clip end the controller passes the argument2 wait first, then sends event0 (`pose_finished`). Native VirtualAC completion conditions remain unresolved.

## Save validation fixes

- `ticks_fraction` must be finite and in [0, 1).
- Pose must be −1 or an integer 0–255; 1.5, NaN and strings are rejected.
- An ending must exactly match one source tuple: (33, HW-BRDGE, 50), (56, E068E, 51) or (57, E069E, 52), with no extra keys.

## Controller

- **Authority split.** The source state owns phase, presence, B5 blocking, owned locals, timers, health/defeat count and the ending. The unchanged generic owner (`scripted_creature_population.gd`) owns bodies, def9 frames, pursuit/attack, player strikes and rewards.
- **Each step:**
  - Generic health loss is mirrored into `State.damage` (kind9, then event10 at zero).
  - Source spawn/remove/wake is pushed into the generic packet.
  - Guards that are present but not `fighting` (B5) are held idle for the generic step.
- **Regions.** Region event2 fires when the player enters one of the source polygons (an entry edge, saved in `inside`). The floor range test is the generic one. Without a supplied context, no region dispatch happens.
- **Pose clips** are billboard quads at the guard body, POSE_SCALE 0.47, bottom at the foot. The clip's voice plays from a 3D player. The generic sprite is hidden while a clip plays.
- **Endings.**
  - The opcode21 movie opens a full-screen overlay and pauses host physics. Saved `movie.elapsed` gives partial playback.
  - At the end, the source reposition (x, z) is applied once. The player keeps the floor found below that point, because source y is 0.
  - The finished packet stays `done`.
- **Integration API.**
  - `setup(host, context: Callable, effects: Callable, saved=null)`: `context` returns `{"shared":{13,14,18,47},"locals":{41,49,51}}`; `effects` receives source presentation effects (object, state, local, presentation/music, actor_command, spawn/remove/pose, movie, applied reposition).
  - `spawn_guards()`: supplied kind5.
  - `advance(delta)`, `checkpoint()`, `restore(packet)` (atomic), `validate(packet)`, `targets()`, `active()`.

## Validation

- `python3 tools/prepare_jungle_exit_movies.py`: PASS, 3 endings and 2 pose clips. A rerun gives byte-identical output (92 files).
- `python3 tools/prepare_jungle_exit_guard_population.py`: PASS (runs native A1D28/A1F2C/A22FB for base15). A rerun is identical.
- `tests/jungle_exit_encounter_state_test.gd`: PASS through `tools/run_regressions.py --test jungle_exit_encounter_state_test` (with `jungle_villager_live_test`, 2/2). Adds hold/partial/resume, an unrelated group continuing, JSON cursor round trip, and NaN/inf/fractional/unknown-ending rejection.
- `timeout 400s tmp/godot_host.sh --headless --path . --script tests/jungle_exit_encounter_live_test.gd`: exit 0 PASS twice (8.4 s). No SCRIPT ERROR; only the existing direct-image-load warnings. Log: `tmp/regressions/claude_exit_live/live.log`.

## Historical handoff limits (superseded where noted)

Items 1–3 below were resolved by the production integration above. Item 5 was resolved
by the Bacatta branch documented in [jungle-bacatta.md](jungle-bacatta.md). Remaining
source/presentation limits should be read together with those newer owner documents.

1. **Melee is blocked by a shared gate.** `cave_melee_reward.gd` accepts reward scale 1–4, but def9's source byte is 10 (`hive_sword_feedback.reward_seed` accepts 1–255). Player melee on these guards is currently rejected with no state change. Spell hits work. A one-line widening in the shared file is needed (not edited here).
2. **Host registration.** `jungle_walkthrough.gd` must instantiate the controller, pass the context provider (shared 13/14/18/47 and locals 41/49/51 from the Jungle owner), add `targets()` to the Spark/spell target list, and route F5/F9 during the movie (as `act_one_departure.gd` does).
3. **Save.** A quest/save key (e.g. `jungle_exit_encounter`) with `validate`/`restore` through `jungle_save.gd` and `act_one_quest_state.gd`, plus runner registration of the live test.
4. **Producers still supplied.** prop552 kind5 (Grok), native opcode8 VirtualAC conditions, event0/event10 and kind9 admission.
5. **Not staged.** The Bacatta/guard60 branch that leaves prop4398 in state0 for E068E is not staged. The test reaches E068E only from a saved state0 packet.
6. **Presentation adapters.** Scale 0.47 (Jungle humanoid adapter). The pose clip's anchor in the 400×248 canvas is unknown. The corpse frame (resource60) is 320×200 but drawn on the def9 400×248 quad, about 1.25× too large; this is a limit of the generic one-canvas-per-definition owner.
7. `docs/jungle-exit-encounter.md` still says poses 8/12 are resource509 entries. That doc belongs to the previous task; the correction is above.
