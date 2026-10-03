# Saved Hive boulder movement

Actors30/31 now appear locally with their original static and rolling frames. Source group6250 activates them; they retain their original spawn height until activation, then use gravity and world collision while following path1. Group6806 latches a stop, consumed at the next rolling terminal. Their frame, timer, sub-tick, signed path index, position and vertical velocity are saved independently.

The implementation reuses the source-checked path-index helper, shared native-frame runtime, explicit-canvas presenter and JSON number rules. The path helper now uses those existing number rules directly instead of importing the entire clock module. The publication's frame validator accepts only selectors present in its supplied clip contract; its existing asset-free combat test still passes.

This is an explicit motion/scheduling adapter: speed160 world units/s, gravity320, sphere radius20/height40, and15360 animation units/s. Only radius/height and source clip/path selection are independently native-bound. Marker flag1024 effects, original motion/gravity/clock conversion, exact callback/queue ordering and presentation scale/anchor remain open. Consuming the state5 stop at a rolling terminal composes individually checked boundaries with a modern schedule; it is not a complete native scheduler replay.

**Player contact response/damage is not implemented.** Original sound cues now have saved playback; see [audio evidence](hive-boulder-audio.md). Boulders collide with world geometry and explicitly exclude the player. They have no ordinary enemy health, melee, spell target or loot behavior. The moving actors do not yet make this a complete hazard encounter.

## Save contract

New saves contain `hive_boulder_actor_schema:1`, both actor slots, and their surface packet. Missing/partial actor data, impossible clocks, or actor activation/stop flags inconsistent with the saved surface phase reject before scene mutation. Loading restores the completed sample; it does not reissue surface callbacks, advance animation, or snap position to a marker.

Old surface-only saves from before phase2 receive dormant actors at the original placements. Old saves already in phase2/3 cannot reconstruct actor history that was never recorded: they persist an explicit `legacy_retired` state and keep these actors hidden/inactive. This preserves those old surface-only checkpoints without spawning a fresh moving encounter midway through them. Complete new packets always restore their actual actor state; malformed packets are never treated as legacy. This compatibility policy is an adapter, not original save-format behavior.

## Checks

The state test checks actor independence, pending-stop JSON restoration at each tick, repeated callback safety, signed reversal and retired legacy behavior. The live test uses production movement functions under one controlled clock and checks600 dormant ticks, source-height preservation, activation, airborne rollback, path/frame continuation, stop rollback, pause, floor support, malformed packet rejection and Jungle disk transport. The rendered capture was inspected: both original boulders appear in the Hive during their fall.

An earned continuation loads the actual hash-verified lower-fight save, uses lift stops5/6 and ordinary jumping/walking, triggers the surface/actor sequence and exits with both actors saved stopped after progressing along the path. This is movement and surface-route evidence; player contact is disabled and earlier campaign legs are reused. It writes new `act1_boulders_earned_exit.json` and `hive-boulders-earned-checks.json`, preserving the earlier surface-only evidence.

Opus and Grok reviewed the proposed design from supplied facts, without code inspection. Their restore-order and stop-latch concerns informed these tests. The suggestion to add a separate path direction was not adopted: native signed progression already defines12→−11 and−1→0→1. Suggestions to reconstruct saved positions from marker indices or accept partial actor packets as legacy were also rejected: transit positions are valid, and partial packets must fail validation.

Publication contains the controllers, state and portable helpers/tests. Full scene/save wiring remains in the local Act One tree with original data staging. Original media and personal saves are excluded.

Validation closure: full99/99 Hive tests pass, including the76.77-second supplied-start quest walk. That run overlapped the final explicit player-collision exclusion and shared-validator cleanup; the final-source boulder live test and native path test also pass. The earned actor continuation passes8.55 seconds, and its actual save hashes and exact actor packets independently match. The report now uses full JSON precision to match saved float values; the earlier rounded report is retained locally. Both boulders stop at path indexes6/7. No complete contact-hazard or Act One claim follows.
