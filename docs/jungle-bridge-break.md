# Huline Jungle wooden plank bridge

This is plank210 at (1466,1205), separate from the earth causeway in the Bacatta/guard exit sequence.

The source support-owner transition sends kind5/value9 when a beast steps onto plank210. Human and lizard forms do not break it. A form change while standing on the same support is not another entry. Predicate206 admits only owner state0. Both source records are selected before execution: group26868 sets local50, creature refusal on region3032, selector1, linked assembly211 and props961–965, and owner state1; group26940 plays sound452. Planks212/213/214 play their source creaks for human/beast support entry.

Selector1 removes the deck children and keeps the posts. The native whole-box collision does not read this selector, so the bridge's solid box remains. The port preserves that distinction. Assembly211 and all five debris props start absent and appear only after the break.

`prepare_jungle_bridge_break.py` pins source records, form dispatch, the selector handler, placements, child masks and region3032. `prepare_jungle_bridge_media.py --game GAME --project PROJECT` stages the original two sprite images and four decoded sounds into a fresh `assets/lol2/generated/jungle_bridge_break` directory. Source media must be present when packaging.

State lives in `quests.jungle_bridge`: version, broken, and support-contact history. The break implies local50=1 and region3032 bit1. There is no other current source reader of local50. Old saves without this feature start with the original intact bridge; malformed current state is rejected before loading. Returning/reloading reconstructs visibility and creature refusal without replaying sound.

Modern adapters: the shared support detector uses a grounded foot position inside the source support rectangle with four-unit height tolerance. Props use the established fixed-Y billboard presentation. Creature refusal uses source-region outline walls between floor and ceiling on a dedicated creature-only collision layer; player movement and aim rays ignore it. Creatures already inside may leave but cannot re-enter. This implements the source refusal outcome, not the native mover algorithm.

Verification is scoped: state transitions and creature-barrier physics have focused headless checks. The actual Jungle crossing test supplies the initial approach and form and manually ticks production movement/support with the host input loop disabled; it does not earn the curse or prove the entire campaign. Run `jungle_bridge_break_live_test.gd` with `--save-path=PRIVATE_FILE`, then in a **new Godot process** with the same argument plus `--restart`. Rendered visual/audio review remains a separate delivery gate.
