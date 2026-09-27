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

Opus’s Cave Aloe planner is independently verified against36 use and980 healing-update cases and published in [PR9](https://github.com/KForestland/lands-of-lore-unified-godot/pull/9). Clean asset-free Godot checks pass. Live Aloe consumption, saved pending healing, no-respawn history and real-time pacing are still pending. Grok is auditing the remaining Act One requirements against the current project evidence.
