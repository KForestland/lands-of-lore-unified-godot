# Jungle watergate and chief's hut

The current source implements the watergate, oil-rock and fire sequence using the original Jungle script records and local media. This is newer than the delivered R4 binaries.

After Kelsrick's conversation, entering a source watergate trigger raises the gate. Looking toward the pool updates its water level. Strike the oil rock with an equipped weapon, then cast Spark at it: fire travels across the oil to the hut. With raised water, the original `HUT-FIRE.VQA` plays and the source completion outcomes run. Returning to the village with no alert releases the village branch.

`jungle_chief_hut_state.gd` owns locals 9/10/11/14. Kelsrick retains locals 6/8, and the alarm retains local 7. Gate changes go through the existing gate owners. Completion decrements Soul once, sets Kelsrick's local 8 to 200, and restores the source floor/gate outcomes. Save files retain water, rock, fire and movie progress; reloading completed state does not replay rewards.

## Source and media

`tools/prepare_jungle_chief_hut.py` prepares the numeric contract and original sprites, floor textures and movie under `assets/lol2/generated/jungle_chief_hut`. The source inventory is preserved at `/home/bob/AI_COMMS/classic_review_20261007/opus/chief_hut/sweep.txt`; preparation evidence is under the neighboring `lead/chief_hut_20261009/` directory. This preparer still uses existing geometry/material exports and local extraction helpers; it is not a complete clean-machine preparation recipe.

Floor-material command values are presets, not resource descriptors: presets 9/29/30/33 resolve to resources 808/41/48/657. Region 3751 rises to -20; the other main pool surfaces rise to -25. The hut movie lookup is independently resolved as `HUT-FIRE.VQA`, 60 frames at 15 fps, with its original audio.

## Deliberate adaptations and limits

- Fire spreads every two seconds instead of the original long timers; the oil-rock animation waits 0.4 seconds and floors move at 20 units per second.
- The original movie appears fullscreen for four seconds. Its completion supplies the source smoke-prop reverse-animation completion event.
- Rock interaction uses a modern collision box and the existing melee/Spark input system. Pool observation uses a visibility/range check.
- Original control/player property commands, the village prop76 timer and ceiling behavior are retained in source receipts where unsupported. Receipt retention does not establish execution or exact parity.

## Review corrections (Opus, 2026-10-09)

- **Spark admission (F1).** The strike's selector command no longer writes the rock's owner state. Only op16 does:
  g15764 (rock animation end with the water up), g20500 and g20778. Source predicate p124 therefore holds, and Spark
  does nothing until the pool has risen; raising it later admits ignition. The rock image follows local10, because
  its selector1 is set only in g15708 together with local10=1. Saves made before this change that already hold the
  old low-water rock state keep it.
- **Oily floors (F2), confirmed correct.** Both strike orders end with the oily presets: g15764 covers
  raise-then-strike and g20500 covers strike-then-raise. No change.
- **Movie lock.** While the fullscreen hut movie holds the player, `world_active()` is false, so creatures, timers and
  other world owners freeze. Before this change an adjacent dinosaur could kill Luther during the movie, which then
  froze on screen. Only the puzzle owner uses `movie_world_active()`, so the movie clock still advances; pause still
  stops it.
- **Source notes.**
  - F3: prop427 is the village fountain (selector1 = spouting). prop561 is the figure thrown by the blast (its fall
    end is g14086), not smoke.
  - F4: control event kind5 is an animation-endpoint event. The pool's visibility check is therefore a modern adapter,
    not a native sight rule.
  - F5: Kelsrick's op9 13/14 toggles control97's flag 0x8000. Whether that flag suppresses its selector natively is
    unresolved. It is not modelled; the source local8>1 predicate is kept.

## Verification checkpoint: 2026-10-09

Seven focused tests pass on unchanged source in `tmp/regressions/chief_hut_integrated_20261009/report.json`: chief state/live, Kelsrick, drunk villager, inner gate, Aloe and sap. These cover supplied approaches, actual armed strike/Spark dispatch, low-water failure/retry, movie progress, pause, disk rollback and one-time completion.

The continuous Hive-fixture-to-puzzle walking test remains under investigation. Initial runs earned the rescue, Kelsrick conversation and inner-gate crossing, then encountered route obstructions before the pool. These are failed walking runs, not end-to-end puzzle evidence. A fresh full suite, campaign and updated exported candidate are still required.
