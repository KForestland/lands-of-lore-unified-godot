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

Opus 5.5 contributed shop callback implementation and source item-producer analysis, and is assigned Julian's post-translation Power Orb sequence. Grok contributed Champion Stone behavior, integration review and a source dagger pickup module. Their outputs require independent integration and verification.

Julian's delayed orb grant, the orb-to-Firestorm exchange and dagger integration are still being checked. Earlier suite and route results do not establish acceptance of these additions. Remaining Act One work includes required item effects, encounter behavior, form/environment interactions, room branches and visual review. Departure retains the original local-state admission rather than adding a rune prerequisite.

## Publication boundary

Publish implementation source, preparation tools and verification documentation separately from locally extracted original game payloads and personal saves. This progress checkpoint contains documentation only.
