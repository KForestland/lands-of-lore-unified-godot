# Remaining Hive encounter triggers

Actor33 and actor35 are distinct encounters. This document records their source verification; subsequent local integration and remaining limits are in [live ambush evidence](hive-ambush-live.md). Act One acceptance remains open. Opus identified the mechanism chains; the lead independently checked source bytes and replayed their conditions, state writers, shared constructor and additional trigger paths.

| Actor | Mechanism | Source activation sequence | Original media |
| --- | --- | --- | --- |
| 33, HIVEW | prop316, template43 | Region444 event2 / local7==0 requests state1 and latches local7. Prop record kind6 carrying event0, owner state1, selects group3810 and enables actor33. | HW07, 25 frames, `HOthr000HWUnfold` |
| 35, EXEC | prop318, template41 | Region716 event4 selects group5648/state1. Event1/state1 selects group4028/selector1/state2; event0/state2 selects group4062, enables prop363 and actor35, then writes state3. A separate kind9 hit filter selects group4022/state1. | EX05, 54 frames, `HOthr000EXEatingHuline`; EX06, 17 frames, `HAppr000EXEatToAttack` |

All three clips are 320×200 at15fps. Template, resource, archive entry and clip hashes are bound in `hive-remaining-actor-triggers.json`. They are different from the existing prop317/actor36 nest clips. No original media is published with this document.

`python3 tools/verify_hive_remaining_actor_triggers.py` passes:

- 768 native predicate cases: all owner-state byte values for predicates2/207/208.
- 3,072 native scanner cases: both full source lists, all256 event values, six owner states. Event1/state1 selects4028; event0 selects3810 or4062 in their respective states. Record kind6 is not event6.
- 1,280 native state writes from the five literal opcode16 producers.
- Five shared constructor records: actors33/35 retain flags0x7182, including inactive0x1000, and state0. Props316/318/363 retain flags0x402/0x4482/0x1002 and state0. Later derived initialization is outside this replay.
- 90 prop318 kind9 hit-filter cases: remaining<=1 selects4022 without a mask restriction. This is not startup event9. Hit production, queue body and level5 feedback are supplied boundaries; repeat-record mutation is not claimed.
- 768 first-contact cases, each with two visits, verify the current-region assignment branch emits event4 once when runtime region flag2 is clear. Three argument cases verify region716's source value0 admits it. SETLE is explicitly supplied; full movement, actor identity and initial runtime region flags remain outside the replay.

The existing `verify_hive_movie_callbacks.py` was independently rerun:160 controller cases,512 callbacks,512 selectors and65,536 activation cases pass. Status5 emits event0; status4 emits event1. Status4 can occur on the first decoded frame, so it must not be described as exclusively a clip-end event. These are composed bounded proofs, not a captured complete native playthrough of either encounter.

Playback, props, saved mechanism state/local7/contact history and combat now have local integration checks. Earned player reachability and actual weapon-trigger binding for prop318 remain open. Region444 event2 producer and prop318 operation10 remain to be checked before assigning their complete observable behavior. The generic constructor result does not by itself prove final post-load activation. Reuse the existing playback/save/combat systems where their behavior matches; do not substitute the current nest animation for the recovered unfold/eating clips.

Verification development caught two harness assumptions: placement flags occupy a16-bit word, and event4 admission calls a shared instruction slice atF2DB7. Both were corrected before the passing report. No gameplay code changed in this work package.
