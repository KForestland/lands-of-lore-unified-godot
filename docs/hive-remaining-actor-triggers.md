# Remaining Hive encounter triggers

Actor33 and actor35 are distinct encounters. This document records their source verification; subsequent local integration and remaining limits are in [live ambush evidence](hive-ambush-live.md). Act One acceptance remains open. Opus identified the mechanism chains; the lead independently checked source bytes and replayed their conditions, state writers, shared constructor and additional trigger paths.

| Actor | Mechanism | Source activation sequence | Original media |
| --- | --- | --- | --- |
| 33, HIVEW | prop316, template43 | Region444 event2 / local7==0 requests state1 and latches local7. Prop record kind6 carrying event0, owner state1, selects group3810 and enables actor33. | HW07, 25 frames, `HOthr000HWUnfold` |
| 35, EXEC | prop318, template41 | Region716 event4 selects group5648/state1. Event1/state1 selects group4028/selector1/state2; event0/state2 selects group4062, enables prop363 and actor35, then writes state3. A kind9 record names group4022/state1, but the native Hive owner318 exception suppresses it. | EX05, 54 frames, `HOthr000EXEatingHuline`; EX06, 17 frames, `HAppr000EXEatToAttack` |

All three clips are 320×200 at15fps. Template, resource, archive entry and clip hashes are bound in `hive-remaining-actor-triggers.json`. They are different from the existing prop317/actor36 nest clips. No original media is published with this document.

`python3 tools/verify_hive_remaining_actor_triggers.py` passes:

- 768 native predicate cases: all owner-state byte values for predicates2/207/208.
- 3,072 native scanner cases: both full source lists, all256 event values, six owner states. Event1/state1 selects4028; event0 selects3810 or4062 in their respective states. Record kind6 is not event6.
- 1,280 native state writes from the five literal opcode16 producers.
- Five shared constructor records: actors33/35 retain flags0x7182, including inactive0x1000, and state0. Props316/318/363 retain flags0x402/0x4482/0x1002 and state0. Later derived initialization is outside this replay.
- Corrected160 hit-filter cases include levels0/5, owners317/318, allocated/missing prop318, four masks and five remaining-durability values. In the actual Hive owner318 case, remaining<=1 clears byte9 and rejects group4022. All96 qualifying control/suppression cases also reject a repeated hit after native condition-byte consumption. The native pool resolver is executed; current level, pool storage and owner identity are supplied. This is not startup event9.
- 768 first-contact cases, each with two visits, verify the current-region assignment branch emits event4 once when runtime region flag2 is clear. Three argument cases verify region716's source value0 admits it. SETLE is explicitly supplied; full movement, actor identity and initial runtime region flags remain outside the replay.

The existing `verify_hive_movie_callbacks.py` was independently rerun:160 controller cases,512 callbacks,512 selectors and65,536 activation cases pass. Status5 emits event0; status4 emits event1. Status4 can occur on the first decoded frame, so it must not be described as exclusively a clip-end event. These are composed bounded proofs, not a captured complete native playthrough of either encounter.

Playback, props, saved mechanism state/local7/contact history and combat now have local integration checks. Earned player reachability and other weapon hit behavior remain open; basic Spark now respects the native prop318 activation suppression. Region444 event2 producer and prop318 operation10 remain to be checked before assigning their complete observable behavior. The generic constructor result does not by itself prove final post-load activation. Reuse the existing playback/save/combat systems where their behavior matches; do not substitute the current nest animation for the recovered unfold/eating clips.

Verification development caught two harness assumptions: placement flags occupy a16-bit word, and event4 admission calls a shared instruction slice atF2DB7. Both were corrected before the passing report. No gameplay code changed in this work package.

Correction after Opus review: the original90-case filter proof forced EAX=0 atAE3C7 and bypassed the level5 owner exception. Its generic acceptance result was incorrectly applied to Hive prop318. The lead independently extended the replay through both native5F878 calls, owner comparison and AE42A byte clear; group4022 is suppressed. The765-case damage result remains valid but does not prove event admission. The provisional live activation added during this follow-up was removed before publication; tests now require no activation from Spark.
