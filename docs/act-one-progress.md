# Act One progress — 2026-09-28

Act One remains in development; this checkpoint does not claim completion or a new playable release. The implementation and detailed verification reports are currently local pending source publication.

## Verified local work

- Weapon shop entry, first conversation, initial item grants and saved dialogue boundaries are implemented. An earned monastery/shop/side-room route, rune translation and departure were checked using linked checkpoints; the earlier legs were reused, not rerun as a fresh campaign.
- Monastery garden and cellar first/repeat/absence rules and partial saves are implemented.
- Magic shop handlers, pickup offers and timer behavior have independent checks covering 1,297 callback cases and 3,840 quip cases, plus rendered inventory and save checks.
- Champion Stone consumption, persistent pickup history, cross-area saves and melee integration have been checked. Timer cadence and direct damage remain explicit modern approximations.
- Executioner melee experience and level growth are integrated; native progression health and playable health remain separate.
- The baseline Hive/Jungle suite passed 60 of 62 checks. Both remaining wax-route checks subsequently passed after the automated walker reacquired mouse capture through the game handler. The underlying capture loss is unresolved; this is a test harness correction, not a claimed game fix.

## Current work and remaining acceptance

Opus 5.5 contributed shop callbacks, Julian's delayed orb sequence, Morgan's blessing and original Museum case geometry. Grok contributed Champion Stone behavior, Jungle dagger pickup and Museum broken-sword behavior. Their outputs undergo independent integration and verification.

Julian's delayed orb grant, Morgan's blessing, the orb-to-Firestorm exchange and dagger integration now have focused checks and linked route evidence. These checks do not establish full Act One acceptance. Remaining Act One work includes required item effects, encounter behavior, form/environment interactions, room branches and visual review. Departure retains the original local-state admission rather than adding a rune prerequisite.

## Publication boundary

Publish implementation source, preparation tools and verification documentation separately from locally extracted original game payloads and personal saves. This progress checkpoint contains documentation only.

## Follow-up integration

Julian's original entry/exit behavior now matches 2,176 local native replay cases. A new earned continuation obtains his delayed Power Orb, walks to the weapon shop, exchanges it for Firestorm and reaches the darker jungle. Eleven actual saves are hash-linked; the first nine are reused from earlier verified runs. This is not a fresh full campaign.

The Jungle dagger and Dagger of Light exchange are integrated. Verification found and fixed the Hive transfer dropping Jungle shop and pickup history; a real Hive save/load round trip now retains those states. The 68-check suite has passing latest results across a full60/68 desktop run and isolated-display follow-ups. The follow-ups use software rendering and do not establish GPU visual equivalence. Original failed logs remain local.

The detached weapon-shop state code and128 admission fixtures are published in [PR6](https://github.com/KForestland/lands-of-lore-unified-godot/pull/6), tested without original assets. Broader live integration publication and Act One acceptance remain pending.

## Museum exhibit and workflow follow-up

The Museum now includes the original stone case and Broken Thohan pickup/return behavior. The sword height was corrected using the native renderer argument order. Four focused checks pass, including rendered pickup/return, inventory holding, disk rollback and transport to Rashar; repair in that test uses a supplied orb. The rendered exhibit was visually inspected.

A separate earned route now starts at the verified cave-derived Museum arrival, walks to the case, takes Broken Thohan, completes the Museum puzzles and reaches the Jungle through the original dragon sequence. The run passed in38.09seconds with actual input/output save hashes checked; the item and exhibit history survive. Earned repair with Julian’s orb now passes the follow-up branch below. Automated steering and accelerated clocks are test adapters.

Morgan’s returned-orb blessing also passes the eleven-link Firestorm departure continuation. Detached monastery state/planner code is published in [PR7](https://github.com/KForestland/lands-of-lore-unified-godot/pull/7). The faster test runner and private-display workflow are published in [PR8](https://github.com/KForestland/lands-of-lore-unified-godot/pull/8), with five runner checks and the portable Godot test passing in a clean publication checkout. Full Act One acceptance and broader live source publication remain open.

## Earned repaired-sword departure

The Broken Thohan branch now has eleven actual hash-linked saves: cave-derived Museum arrival and pickup, Hive rescue/flute/wax/runes, Rashar’s orb-knowledge discussion, Julian’s translation and delayed orb, Morgan’s blessing, Rashar’s repair, and darker-jungle departure. The cave leg is reused; downstream legs were rerun. Final inventory contains one repaired Thohan and neither the consumed orb nor broken sword. Museum exhibit history and the original quest flags survive. This is branch verification, not full Act One acceptance.

The walk to MAGIC exposed an open gate leaf blocking the automated central approach. A source-connected west-side approach passes with normal collisions and player dimensions. A stale rune test assumed total fighting XP200; it now verifies the source reward’s200-point increase while preserving earned Executioner experience across level thresholds.

Opus’s Cave Aloe planner is independently verified against36 use and980 healing-update cases and published in [PR9](https://github.com/KForestland/lands-of-lore-unified-godot/pull/9). Clean asset-free Godot checks pass. Live Aloe consumption, pending-heal saves and no-respawn history now pass in all four areas. Cadence and health units remain explicit modern adapters.


2026-09-28 verified update: fresh Aloe-integrated Hive suite passes75/75. Earned cave entry through Aloe harvest/use after real injury to Museum passes290.35s; health24→30, mana17 unchanged, consumed history and actual save hash verified. Lowest-charge Executioner Spark magic XP now passes source binding,25,792 native reward cases and six distinct focused checks including growth, mana ordering, rollback and Hive-to-Jungle transport. The75-suite predates Spark integration; current77 suite not rerun in full. [PR10](https://github.com/KForestland/lands-of-lore-unified-godot/pull/10) commit ce18219 publishes detached planner/5902 sanitized numeric fixtures with clean asset-free testPASS. Grok is investigating Ancient Stone use with admission-only evidence; no effect promoted. Full Act One remains OPEN.

The [actor coverage audit](act-one-actor-coverage.md) now enumerates194 source placements across the four pre-departure archives. Four live encounter bindings were explicitly reviewed; other placements need classification against source activation and existing scene owners. This is not a completion percentage or a claim that every placement is a mandatory enemy. The eleven-save repaired-sword departure chain was independently rechecked and still passes.


## Hive transformation follow-up

Translation-gated regions812/818 now work through the existing runes-translated flag. Source command04 is a one-shot human return, used in four regions391/818/1259/1260; command3c remains repeatable. Live integration preserves slope contact, pending-return saves and consumed-command history through Jungle transport. Native checks cover256 predicate cases,36 dispatch cases and24 human-request cases. Native timing and mutation lifetime across original level reload remain explicit adapter limits.

A fresh **78/78** Hive suite now passes, including Spark/Aloe, the new gates, shared saves and the live Hive quest walk. Six focused gate/save checks also pass. These tests do not establish full Act One content or owner acceptance. Detached gate state and numeric fixtures are in [PR11](https://github.com/KForestland/lands-of-lore-unified-godot/pull/11), with a clean asset-free test.

Ancient Stone's counter is statically bound to free highest-charge attack-spell consumers, with per-spell admission exceptions. Basic Spark remains a separate effect. The highest-charge implementation is now integrated as described below.

## Ancient Stone and lightning aura

Ancient Stone inventory use now adds a saved free maximum-charge cast. Maximum Spark creates the original effect type: a protective lightning aura with repeated homing level0–3 bolts, health reduced to one, timer extension on recast and gradual recovery after expiry or transformation cancellation. Basic Spark does not spend the stone counter. Original timing, damage, target predicates and presentation still have explicit adapter limits.

Opus supplied the aura source binding; the lead independently checked it and replayed180 expiry cases plus three incoming-hit condition-gate cases. Grok's earlier save review informed integration after correcting its counter-cap and pickup-history assumptions. The local live test covers actual stone pickup/use, multiple targets, combat protection, repeated Executioner magic-only XP, in-flight rollback and Jungle transport, using documented room/combat fixtures.

A fresh **81/81** Hive suite passes, including the live quest walk in72.88seconds. This is regression coverage, not exhaustive Act One acceptance or a new full campaign run. The detached state model and exact state-only test are published in [PR12](https://github.com/KForestland/lands-of-lore-unified-godot/pull/12), tested in a clean checkout without original game assets. Broader live integration remains local. Actor activation classification and remaining content/presentation work stay open.

## Hive reinforcements and spell reward corrections

Seven return Hive warriors now activate from the rescued-Shalla and met-Bacatta quest flags, using source positions, 400 health and reward scale8. Activation, damage, defeat history and positions persist through saves and Jungle travel. Opus identified the original startup event scanner; independent verification covered four scanner cases and16,384 event/predicate combinations. Movement, attack timing and original startup-list lifetime still have explicit adapter limits.

Grok's review exposed missing guardian/roach spell experience and an overkill reward error. Both are fixed locally. Independent native checks cover6,144 damage-result cases and four dispatches; focused live checks cover actual health lost, reward scale, RNG persistence and corpse rejection.

All **84 latest regression results pass**: the full run passed82/84, followed by passing focused reruns after correcting two legacy route expectations. This is not a fresh single84/84 run. An earned continuation from the verified Hive-entry save completed rescue, Bacatta, the flute quest and Hive return in172.21seconds. Actual input/output hashes and quest flags were checked; all seven reinforcements activated with400 health. They remain alive in that route; separate focused tests cover their combat. The prior eleven-save repaired-sword departure chain still passes its independent audit.

The actor audit now records194 source placements and11 positively reviewed live bindings, not a completion percentage. Detached reinforcement save state and numeric fixtures are published in [PR13](https://github.com/KForestland/lands-of-lore-unified-godot/pull/13), with its exact state test passing in a clean checkout without original assets. Shared save validation also updates [PR12](https://github.com/KForestland/lands-of-lore-unified-godot/pull/12). Broader live integration remains local. Full Act One remains open: other actors, item effects, form/environment interactions, room branches and original presentation still need completion and review.

## Next encounter source verification

[Hive actors33/35](hive-remaining-actor-triggers.md) now have independently checked activation chains, initial shared-constructor flags and original unfold/eating-to-attack media bindings. Native checks cover768 predicate cases,3,072 event cases,1,280 state writes,90 hit filters and768 two-visit contact cases. Opus contributed the source-chain analysis. These are missing live encounters; the verification identifies their implementation requirements and does not increase live actor coverage or establish Act One completion.

## Live unfolding and feeding encounters

The two additional Hive encounters now activate through source-region checks and play their original96 animation frames before combat. Melee, basic Spark, aura, partial saves, defeat and Jungle transport pass focused tests. The lower Hive chamber exposed a shared save-height limit that is now corrected. [Live evidence and remaining limits](hive-ambush-live.md).

A fresh full **86/86** Hive suite passes, including the continuous quest walk in73.42seconds. The eleven actual repaired-sword departure save links still pass their independent audit. These tests do not establish earned approaches to the two new encounters or a fresh full campaign. The actor audit now has13 positive bindings across194 placements, not a completion percentage.

Portable ambush state is in [PR14](https://github.com/KForestland/lands-of-lore-unified-godot/pull/14), commit28d687b, and aura target support updates [PR12](https://github.com/KForestland/lands-of-lore-unified-godot/pull/12), commit6fd8467. Both documented clean-checkout tests pass without original media or saves. Broad live integration remains local. The previously proposed Spark activation path is withdrawn by the native exception check below. Next is earned reachability and remaining native combat/presentation work. Full Act One remains open.

## Corrected feeding-prop hit behavior

Opus found a Hive-specific exception that the earlier generic hit-filter replay skipped. The lead independently replayed160 level/owner/allocation cases and96 consumed-record repeats: basic Spark can deplete prop318, but the native Hive owner318 filter disables its condition and suppresses activation. Region716 remains the activation route. The earlier765 damage cases are valid damage evidence, not activation evidence.

The live cast now leaves feeding and transition stages unchanged, retains the consumed condition through saved travel, and still permits normal region activation. Four focused tests and a fresh full87/87 Hive suite pass, including the continuous quest walk in71.09seconds. [PR14](https://github.com/KForestland/lands-of-lore-unified-godot/pull/14) commita94b519 publishes the updated state and tests, with a clean portable test pass. Original event-record lifetime across reload, other weapons, earned approaches and full Act One remain open.


## Earned feeding encounter

Two hash-linked continuation checks pass from the earned flute-return save: normal walking, lift controls and jumps reach region716; actual maximum Spark and aimed melee defeat the feeding Executioner; normal movement returns the player to the lift. Accelerated runs took5.51 and3.37seconds. Earlier cave/flute legs are reused. The lower unfolding warrior remains unactivated and its earned approach remains open.

The harness now drives the curse clock once per movement/wait tick. Grok’s read-only approach review found no confirmed defect; it did not execute the test. Opus’s environmental-effect investigation reached its bounded turn limit without a verified conclusion. Production code is unchanged from the87/87 regression checkpoint. Original combat fidelity and full Act One acceptance remain open.


Lower-chamber follow-up: two earned attempts obtained lizard form naturally but stopped at a narrow passage. Source floor/ceiling checks reject the candidate connection because it has no vertical opening; the lower encounter is still unproven. No collision was weakened. A separate pinned-source audit confirms that the flute’s selector-state request has an upper-stop callback, preserving the current lift behavior. Further environmental effects remain unresolved; no lava damage or universal flute gate is inferred.


## Lower Hive encounter and recovery fix

The earned continuation now uses lift stop4’s west landing, follows81 source-connected regions to the unfolding warrior, defeats it, and returns to the lift. Approach and fight/return checks pass in8.70 and8.05seconds under the accelerated harness; actual save hashes link both legs. Final saved actors33/35 are defeated. Earlier cave/flute legs are reused, and original combat/presentation fidelity remains open.

This route exposed an inherited−2048 void-reset threshold inside legitimate Hive terrain. Recovery now remains below the lowest staged floor with an explicit512-unit adapter margin: Hive−3512, Jungle unchanged−2048. A focused rendered check verifies normal movement on the−3000 floor and actual void recovery in both areas. No terrain or player collision was weakened. The previous narrow-passage candidate remains rejected.

The fresh full **88/88** regression suite passes, including the continuous supplied-start Hive quest walk in72.39seconds. Grok’s review prompted explicit failed/dead-run rejection and an initially-inactive encounter check in the earned harness; hardened approach/fight reruns pass10.60/9.30seconds with actual save hashes verified again.

Warrior animation preparation now has independent native proof for seven frame counts,1,792 event matches and912 clock updates. The shared runtime matches those updates and retains passing Executioner/portable checks. All98 first-view frames are decoded locally with round-trip checks; source variant selection, directional views, special-pixel composition and live integration remain pending. See [warrior animation evidence](hive-warrior-animation.md). The latest full88 suite predates this focused runtime-contract change.

Warrior variant selection now passes21,504 native lookup cases,7,236 native health-mask updates and2,048 terminal death/corpse branch cases. The deterministic selector/mask planner and numeric fixtures are published in [PR15](https://github.com/KForestland/lands-of-lore-unified-godot/pull/15), commit74d1402, with a clean asset-free Godot test. Live animation integration remains next; special-mode cleanup and original callback effects stay explicit limits.


Warrior death/corpse presentation is now integrated locally for return warriors23–29 and lower warrior33. Partial frames, living rollback, pause, legacy saves and Jungle transport pass; the full91-check suite and final two-test follow-up pass. The earned lower fight/return rerun saves a visible corpse. [Evidence and remaining limits](hive-warrior-death-live.md). Attack animations and full Act One remain open; this PR remains documentation only.
