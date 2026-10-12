# Lands of Lore 2 Classic completion plan

Updated 2026-10-12. Owner: Kjetil. Integration lead: Codex/Astra.

This revision answers the owner’s overview/research/task-list request and makes cross-location UI, skills, magic and item continuity an explicit release gate. Historical Bob references below refer to Kjetil.

The main goal is to finish the complete original Lands of Lore 2 Classic in Godot. The first delivery milestone is a playable Act 1 demo, from Draracle's cave through departure to the darker jungle. The demo is an intermediate release of the same game and codebase.

[Classic Edition](classic-edition.md) remains the fidelity contract. Bob’s 2026-10-07 direction permits modern mechanics when better or faster; exact replication is not required. Enhancements and other games do not displace this plan. Existing dated test results certify their recorded revisions only.


## Current overview and priority — 2026-10-12

Finish a reliable, connected Act 1, then extend the same campaign into later areas. Preserve the game’s function and recognizable interface; use modern implementation when it saves time. Exact native algorithms, timing and pixel replication are not gates unless a difference breaks gameplay or an agreed presentation requirement.

| What we have | Evidence and practical limit |
| --- | --- |
| Playable Cave, Museum, Huline Jungle and Hive, with connected rooms and quests | Four partial areas in [coverage](game-coverage.md). Playable does not mean every original interaction is complete. |
| Verified R14 candidate | Fresh 326/326 regressions, 11 linked campaign legs including Kityara, 21,333 matched packed assets, both exports and actual Linux save/restart/Jungle checks PASS. [R14 verification](act-one-r14-verification.md). Full content/owner acceptance open; R13 retained. |
| Owner-tested R13 hotfix1 | Current-state record says Museum jump and coordinate/F8 overlay accepted. This is separate from R13 qualification and full Act 1 acceptance. |
| Qualified source | R14 includes tavern/LIZ, HUD and continuity work published through 1fcee47. Archived source hashes identify the tested baseline; the shared checkout Git HEAD alone does not. |
| HUD work | R4 integrated 2026-10-12: shared skill/XP Character display; corrected semantic continuity checker; Cave→Museum→Jungle and separate-process reload PASS, including two R13 saves. Hive→Jungle return/disk and invalid-packet checks PASS separately. See [review](hud-r4-continuity-review.md) for supplied fixtures and limits. R14 full-suite/campaign/package qualification now passes; see [verification](act-one-r14-verification.md). |
| Source material for the whole game | All 15 numbered level archives freshly hashed and parsed against the inventory: 52,669 regions, 1,028 actor placements and 17,342 prop placements. All matched. These are source records, not completed gameplay or unique species/items. [Fresh check](forward-plan-source-checks-20261012.json). |
| Tools and assets | MIX/geometry/command readers, source identities, extracted media, manual, native traces, Godot scenes, save validators and focused/campaign test drivers. Reuse these before starting another investigation. |
| Shared progression foundation | Magic, fighting, item effects, equipment and area handoff code already exists; dedicated tests inspect transport and disk rollback. Full spell coverage and every boundary remain to be audited. |
| Later campaign | Eleven numbered areas are source mapped, not integrated according to the whole-game board. Their archive abbreviations are not yet an accepted gameplay/name mapping. |

Immediate order: playtest verified R14 → reconcile remaining required Act 1 content gaps → implement Savage Jungle continuation while retaining the continuity gate. Combat tuning and reported cave/inn repairs retain their current deferral; record and localize them, then promote any confirmed critical-route blocker explicitly. The initial planning pass changed documentation only; subsequent HUD/continuity integration and R14 qualification are recorded above.

## Research findings and evidence use

Research checked 2026-10-12. Walkthroughs are guides to intended player outcomes; local source and ordinary gameplay establish triggers. A guide’s omission is not proof that content is optional or absent.

| Source | Finding or use | Evidence limit / next check |
| --- | --- | --- |
| [Crash’s walkthrough, Just Adventure](https://www.justadventure.com/walkthrough/lands-of-lore-2-guardian-of-destiny-walkthrough/) | Separates main goals, side quests and evil branches. Describes direct Shining Path versus Museum exploration and later campaign groups through the final chambers. Useful checklist structure. | Historical guide, not executable semantics. Test both departure alternatives; do not infer the source archive/name mapping from prose alone. |
| [Lands of Lore Wiki walkthrough](https://lands-of-lore.fandom.com/wiki/Walkthrough_%28Guardians_of_Destiny%29) | Describes the rescue, village/monastery, flute, wax-copy and departure dependencies; highlights early ivory chips needed much later. | Cross-check acquisition and consumption with local item identities. Main-route completion cannot certify those delayed dependencies. |
| [Mike Marcelais walkthrough](https://rpggamers.com/walkthrough/lands-of-lore-2) | Additional account of jungle detours, equipment and repeat visits. | Corroborating route source; do not copy numerical item balancing into code without checking our existing catalog/evidence. |
| [Most Difficult longplay](https://www.youtube.com/watch?v=xXNHBdF9rC4) | Located an original-game longplay for route, HUD and interaction comparison. | Search metadata accessed; direct playback fetch failed. No footage or timestamps newly verified. Difficulty-specific behavior must be separated from general rules. |
| [Aqua Walrus review/playthrough](https://www.youtube.com/watch?v=d4HdA6ZOdNQ) | Metadata lists gameplay at 06:15 and story playthrough at 17:38; useful overview reference. | Edited review, not exhaustive route evidence; playback fetch failed. Chapter times come from the description. |
| [Kikoskia: The Draracle](https://www.youtube.com/watch?v=N05rwQTWKsw) | Existing [chamber study](chamber-sequence.md) connects storyboard previews and decoded local films to the Cave/Museum sequence. | Prior storyboard-only evidence, approximately 312–351s Kenneth, 356–445s discussion, control around 544s. Not newly watched or audio-verified. |
| Local original manual and archives | Manual-backed form rules distinguish ownership from ability to use gear. Fresh archive checks validate our source inventory and command framing. | Framing is not behavioral proof. Use [form/manual evidence](player-form-manual-evidence.md), existing source readers and bounded native checks for unresolved rules. |

For each researched behavior, keep one row: area/source identity → prerequisites → ordinary action → visible result → persistent change → allowed repeat/return → reference/evidence → implementation status. Record video URL/time/edition only after actually reviewing that segment. Start with Cave→Museum and both Museum departures, Jungle↔Hive, village/monastery/shop visits, then darker-jungle departure. Original movie assets establish content, but not when that content should trigger.

## Cross-location continuity contract

One logical player state must survive A→B→C. The same HUD must read that state in every area. Area loading may change position, local actors and camera; it must not recreate a fresh player or regrant consumed rewards.

Existing implementation is distributed, not absent: `cave_walkthrough.gd` emits `_completion_state()`, `museum_walkthrough.gd` validates it and emits `inventory_state()`, and `jungle_walkthrough.gd` provides `area_handoff()` / `apply_area_handoff()`. `player_fighting_transport.gd`, `player_magic_state.gd`, `player_item_state.gd` and save validators already support this. Jungle moves magic/fighting into quest-owned state; merely searching its inventory dictionary would incorrectly suggest those fields were lost.

Extend these adapters incrementally into one versioned transfer contract. Do not rewrite working scenes or force an autoload redesign before a demonstrated need. Validate the complete destination packet before committing; a failed transition keeps the source state usable. Required fields cannot silently fall back to fresh-game values. Migrate older saves explicitly and test them.

| State | Required behavior | Acceptance observation |
| --- | --- | --- |
| UI | Common layout, controls, equipment/health/mana/skill displays and selected actions in all areas. Cursor/modal state resets deliberately and safely after travel. | Real inventory, Heal, Attack, magic-selection and save/load clicks work in each host at two resolutions; no duplicate panel, hidden status or stale bars. |
| Skills/progression | Fighting and magic experience, levels, learned abilities and maxima survive. | Earn progression in A, use it in B, earn more, verify combined result in C and after restart. Never award the same event twice. |
| Magic | Mana/maxima, selected spell, learned spells and applicable cooldown/effect state survive. | Cast before and after travel; compare saved values allowing documented elapsed-time effects. Starting Spark/Heal coverage must not be presented as all-spells coverage. |
| Items/equipment | Stable item IDs, quantities, charges, consumed history, weapon/armor/offhand and effect ownership survive. | Pick up/use/equip in A; inspect and use in B/C; no duplicate, lost item, refilled charge or respawn on return. |
| Form/health/status | Health, curse/form, restrictions and relevant active effects follow one policy. | Beast/Lizard may disable gear without deleting it. Travel/load does not count as a transformation or heal the player. |
| Quests/world | Dialogue decisions, rewards, switches, dead actors, collected pickups and visited-room state persist in their area namespace. | Return where allowed; solved puzzles stay solved and paid rewards stay paid. One-way boundaries do not acquire invented return routes. |
| Persistence | Versioned validated snapshot, compatible migration and recoverable writes. | Save in each area, quit the process, restart and continue. Reject bad/conflicting data without partial mutation. |

The first acceptance matrix is:

1. Cave → Museum → Jungle: earned cave gear, one consumed item, non-default health/mana, selected spell, fighting/magic XP and form state. Exercise the direct-exit branch separately from Museum exploration if both are supported.
2. Jungle → Hive → Jungle: flute, wax, rescue/rune flags, charges, gained XP and local world changes; revisit after disk restart.
3. Jungle → village/monastery/shop/side room → Jungle: item exchange, consumed equipped item, spell/knowledge reward and repeat conversation. Room overlays count as state boundaries even if they do not change Godot scene.
4. Jungle → darker-jungle continuation: preserve the full continuation save; the current route boundary is not evidence of a playable later campaign.
5. Failure cases: missing destination asset, rejected state, interrupted load, repeated trigger, death/reload and legacy save. Keep old state intact or use a documented recovery path.

Reuse `player_magic_handoff_test.gd`, `cave_fighting_handoff_test.gd`, `captain_equipment_transport_test.gd`, item/form tests and the existing 11-leg driver. Their direct state injection is useful component coverage, but does not replace an ordinary-input route. Add one reusable semantic before/after comparison with explicit allowed deltas (travel position, genuine spending/reward, permitted elapsed time). A missing field must fail the comparison. At least one negative control that drops an earned item or XP must fail, proving the checker detects loss. Keep screenshots for HUD agreement as well as state receipts. These expanded checks are planned, not newly run.

## Modernization rules that save time

- Reuse Godot movement, collision, input, media and UI systems where the observable result is right. Keep stable original object/item IDs for evidence and saves.
- Implement a complete trigger → result → persistence → return slice before polishing optional visual details. Do not ship an untriggerable feature because its helper test passes.
- Consolidate repeated item/effect hooks only where two real features demonstrate the benefit. Preserve effects, cleanup and save behavior through the extraction.
- Prefer data-driven room/quest tables for known patterns. The earlier advisory room-DLL interpreter proposal is a bounded experiment, not a prerequisite for completion; unknown calls must remain visible and existing rooms must remain available.
- Look in existing docs/readers first. Time-box each unresolved research question to a decision: reuse known behavior, explicit modern adapter, or a clearly named blocker. Deep tracing is justified when it can resolve a specific player-visible uncertainty.
- Run focused affected checks while developing, then full/campaign/package checks on a frozen candidate. Avoid rerunning long suites merely to refresh a status count.
- Track accepted behaviors and open dependencies, not asset/test totals as completion percentages. Record material differences in the same behavior row.

## Milestones from the current build to completion

| Phase | Work and deliverable | Exit gate |
| --- | --- | --- |
| 0 Establish the baseline | Inventory current code, pending changes, saves, assets, active owners and reproducible build commands. Reconcile current evidence and content gaps. Preserve a recoverable snapshot. | One identified revision and asset manifest; focused baseline checks; discrepancies recorded without erasing historical evidence. |
| 1 Prove the shared architecture | Trace item and player state ownership. Pilot shared item registration and validation on one existing item; use the cave captain encounter as the candidate complete encounter. Review health and damage scales together. | Pickup/reward, equipment/use, combat where applicable, save/load, failure/retry and area return retain expected behavior. Save compatibility is demonstrated. |
| 2 Complete Act 1 content | Close the cave, Museum, Jungle, Hive and connected room requirements. Finish original interactions, encounters, loot, quests, forms, transitions and recovery. | Every required Act 1 behavior has an owner and playable evidence; optional original content is inventoried with explicit status. No progression, crash or save blockers. |
| 3 Deliver the Act 1 demo | Freeze a candidate, run the fresh campaign and branch checks, fix presentation defects, export and package it, then address Bob's playtest notes. | Demo acceptance checklist below passes on the shipped revision. Bob accepts the demo. |
| 4 Expand through the remaining campaign | Bind remaining area names and quest dependencies, then implement complete connected area packages in verified progression order. Extend reusable systems only as needed. | Every original area, interior, quest branch and ending has an implementation status; the entire critical campaign is playable. |
| 5 Reach whole game alpha | Join the completed packages into a fresh start-to-finish campaign, including ending, saves, deaths, retries and revisits. | A continuous earned playthrough reaches an original ending without debug shortcuts. Other original branches/endings have dedicated checks. Remaining defects are explicit. |
| 6 Complete Classic fidelity and acceptance | Close missing original content and player-visible defects; tune modern mechanics through playtesting. Verify supported builds and performance. Bob reviews each area and reported fix. | All updated Classic Edition requirements pass. Material modern-mechanics differences are documented; Bob accepts the playable result. |
| 7 Release and preserve | Produce the accepted build, source revision, asset preparation instructions, checksums, change notes and recovery archive. | A clean setup reproduces the release; packaged smoke checks pass; shipped artifacts match the accepted candidate. |

Phase 1 is a bounded improvement within delivery. Unrelated architecture work stays queued. Shared-system corrections can continue during content work, but each must remove a demonstrated defect or repeated integration cost.

## First action queue — ordered work

These are planned tasks, not new collaborator assignments. The lead verifies active ownership before edits. Kjetil supplies acceptance; technical reproduction and QA remain the implementer’s responsibility.

| ID / priority | Task | Depends on | Done when |
| --- | --- | --- | --- |
| P01 / now | Pin source/assets, private HUD release and current build; reconcile stale open rows against newest receipts. | None | One reproducible baseline; integrated/private/delivered status separated. Planning audit completed; implementation baseline pin remains open. |
| P02 / now | Finish original HUD integration and inspect all four hosts. | P01, corrected private release | Real clicks, notices and status work; two resolutions; no duplicate panel or overlap; save identity preserved. |
| P03 / now | Inventory persistent fields and add the shared semantic continuity check described above. | P01 | Every UI/skill/magic/item field has an owner and migration rule; existing adapters reused; dropped-field negative control fails. |
| P04 / next | Run A→B→C, return and process-restart checks with actual earned saves. | P02–P03 | Matrix cases have state comparisons, screenshots and linked save hashes on one revision. Fix losses before adding areas. |
| P05 / next | Reconcile Act 1 behavior ledger from walkthroughs, source records, existing feature docs and observed playtest failures. | P01 | Each required/optional branch has status, ordinary trigger, evidence and next action; deferred cave/inn issues explicit. No invented Museum prop93 reward without an actual producer. |
| P06 / next | Close required progression/trigger gaps one complete slice at a time. | P05; P03 for state-changing work | Ordinary player can trigger the behavior and continue; save/retry/repeat/return checked. Combat tuning stays deferred unless a route blocker requires intervention. |
| P07 / milestone | Freeze next demo; run full applicable suite, fresh campaign and actual packaged checks; owner playtest. | P04, required P06 | Delivered artifact matches checked source/assets. Known omissions explicit; Act 1 acceptance is separately recorded. |
| P08 / later | Bind L8_SJ and adjacent archive identities, prerequisites, interiors and exits; build first later-area slice. | Act 1 gate and source/route mapping | Act 1 continuation enters a useful playable next area with all player state intact. Archive number alone is not route order. |
| P09 / later | Expand in connected campaign groups through remaining quests and endings. | P08, then each preceding dependency | Every added area passes the same continuity gate; optional and mutually exclusive branches have their own checks. |
| P10 / release | Fresh whole-game campaign, supported-platform testing, clean asset preparation and owner acceptance. | P09 | Reproducible accepted release with continuation/migration, recovery, controls and documented modern differences. |

First bounded implementation batch: P01–P04. Success is one consistent HUD and a demonstrated no-loss Cave→Museum→Jungle→Hive/return chain, not a larger test count. Estimate later batches after measuring this one; no unsupported full-game ETA.

## Act 1 demo acceptance

The demo uses the production campaign and save model. It must not become a separate implementation. Its ending is the existing darker-jungle departure boundary, with a retained continuation save.

- Start a new game and finish cave → Museum → Jungle and required connected quests → darker-jungle departure using ordinary controls.
- Complete required combat, conversations, puzzles, pickups, equipment, spells and form abilities. Check failure, death, retry and repeat interactions as well as success.
- Cover original optional content within the demo area. Any deferral is named in the demo notes and remains tracked for Classic completion; do not silently omit content to pass the gate.
- Verify save/load mid-encounter and mid-conversation where supported, item consumption, no unintended respawns, cross-area travel and return visits. Retain a documented save migration path for the full game.
- Resolve incompatible health/damage/progression scales and other provisional rules that break the route or materially misrepresent play. Record remaining demo fidelity limitations separately from completed work.
- Run focused checks during development, then the full applicable suite and a fresh rendered earned campaign on the frozen candidate. Use separate branch runs for mutually exclusive outcomes.
- Match actual input/output save hashes for every campaign leg. Preserve source and asset fingerprints, logs and screenshots in a unique evidence directory.
- Perform representative GPU visual checks and audible playback checks. Private Xvfb checks alone do not certify those properties.
- Export a repeatable build with launch instructions, controls, save location, build ID and concise known issues. Verify launch and save/load from the exported package in a clean user-data location.
- Bob playtests the candidate; the lead reproduces, fixes and verifies reported blockers before acceptance. Demo acceptance does not imply full Classic acceptance.

The existing [Act 1 content checklist](act-one-completion.md) supplies the detailed scope. Its dated entries must be reconciled before scheduling; older “open” items may already have newer implementation evidence.

## Remaining campaign implementation order

The [coverage inventory](game-coverage.md) accounts for 15 numbered source areas. Archive numbering and decoded exits do not establish quest order. Bind names, admission conditions, interiors, revisit behavior and ending dependencies before committing an area package.

After the demo, investigate the L8_SJ continuation and connected L9_DR/L10_DC, L12_CM/L13_RC and L14_HT branches. Source connections then expose L16_CA, L17_HC, L19_BC and L20_BB. L7_DH and every connected interior must be classified against Act 1 and later progression. These are planning groups from the source graph, not a claim that all routes are playable or that their sequence is known.

For each area package:

1. Identify its original content, entry prerequisites, exits, optional branches, return states and player capabilities.
2. Bind geometry, collision, materials, actors, items, dialogue and scripts to stable source identities. Record unsupported data explicitly.
3. Implement complete encounters and quest steps using shared state and behavior systems.
4. Verify trigger/result, failure/retry, save/load and arrival/departure behavior, including a return visit where original rules allow it.
5. Extend the earned campaign to the new boundary. Preserve prior branch evidence and run affected regressions.
6. Review representative original visuals, audio, timing and performance; issue a build for Bob's area review.

All original spells, forms, equipment effects, enemies, NPC branches, cutscenes and endings must appear in the inventory, including content that has no separate map archive. Whole-game alpha establishes continuity; final Classic acceptance closes the remaining fidelity and content work.

## Engine boundaries and migration rules

| Owner | State or responsibility |
| --- | --- |
| Player state | Health, mana, progression, inventory, equipment, form, curse and active effects. |
| World state | Stable area/actor/item identities, quest flags, collected items, defeated actors and persistent mechanisms. |
| Behavior systems | Combat, movement/navigation, dialogue and event rules with explicit inputs and resulting effects. |
| Presentation | Sprites, audio, camera and UI derived from behavior; presentation clocks are preserved where needed. |
| Persistence | Versioned snapshots, validation, migration, atomic application and recovery. |
| Area controllers | Assemble content and connect local events to the shared owners. |

Migrate in this order: shared item registration/validation → player ownership and travel → world-state namespaces and save migrations → explicit behavior/presentation interfaces. Preserve proven creature, audio, navigation and renderer components. Do not replace working subsystems solely to match this diagram.

Each extraction must name the repeated edits or defect it removes, retain old saves or supply a verified migration, and show equivalent behavior on a representative route. Trial a common interface on a second distinct content example before broad rollout. Avoid a universal scripting framework until repeated source behaviors justify it.

## Team workflow

The lead owns priorities, shared integration, independent review, evidence promotion and releases. Opus handles bounded architecture or content slices. Grok handles bounded source uncertainties and adversarial rule review. Bob owns canon decisions and playtest acceptance; agents own technical QA and reproduction.

Maintain at most one implementation assignment per collaborator plus the lead's integration task. Every assignment names the observable behavior, evidence inputs, exact files, deliverable and stop condition. Require acknowledgement before treating a collaborator as active. Checkpoint findings within the first bounded run; if inconclusive, report competing hypotheses and the next discriminating test rather than restarting broad research.

Use isolated branches/worktrees where practical. Shared files have one editor at a time. Freeze the candidate used for acceptance; later work continues separately. A passing run on moving source is useful diagnostic evidence, not acceptance of a single revision.

Use the existing coverage JSON as the area status source; do not edit its generated Markdown board independently. Keep the task queue short and link evidence. Archive chronological reports instead of appending them to current-state summaries. Model advice becomes accepted evidence only after independent checking.

## Tools that reduce repeated investigation

- Maintain a provisional-rule register with current value, evidence, affected content and replacement condition. Start with health/damage, movement, interaction reach and clocks.
- Add a small developer inspector when the pilot needs it: selected object's source identity, current state, blocking predicate, last event and save owner.
- Add bounded deterministic behavior comparisons where useful: recorded inputs, controlled clock/RNG and meaningful event/state differences. Compare pre/post migration; use original reference results where available.
- Keep evidence immutable per run, including failed logs. Distinguish harness corrections, source rule corrections and presentation corrections.
- Automate a concise status summary from maintained records after their fields are stable. Show what became playable, what remains blocked, and the next acceptance gate.

## Progress and scheduling

Track completed playable behaviors, remaining required/optional scope, reopened defects, integration time per comparable slice, and unresolved fidelity issues. Test counts and extracted asset counts are evidence volume, not completion percentages.

At each completed slice, update status and dependencies. At each milestone, review the critical path and revise estimates. Establish an initial forecast after baseline reconciliation and two representative accepted slices, using observed integration/QA time and a range for unresolved research. The older September delivery aspirations are not a new deadline.

Escalate a research question only when it blocks an implementation or fidelity decision. Stop tracing once that decision is supported. If an architecture task does not reduce a demonstrated delivery cost, defer it and continue content completion.

## Final release checklist

- All original content and supported ending branches accounted for and accepted.
- Continuous start-to-finish campaign, branch checks, death/retry and cross-area saves verified on the release revision.
- Intended gameplay, recognizable UI, presentation and audio accepted; temporary rules either resolved or documented as approved modern behavior. Exact timing/pixel parity is not required.
- Supported platform/rendering configurations recorded and tested; performance and crash/save blockers closed.
- Bob's area notes resolved and Classic acceptance recorded.
- Build and source identifiers, local asset prerequisites, conversion commands and checksums recorded; original media and personal saves excluded from source publication.
- Clean export/install smoke checks pass; accepted build, evidence and recovery snapshot preserved.

## Related project records

- [Classic scope](classic-edition.md)
- [Active restoration plan](restoration-plan.md)
- [Act 1 completion inventory](act-one-completion.md)
- [Whole game coverage](game-coverage.md)
- [Map and visual checklist](execution-checklist.md)
- [Implementation workflow](/home/bob/AI_COMMS/ACT1_IMPLEMENTATION_WORKFLOW.md)
- [Task queue](/home/bob/AI_COMMS/TASK_QUEUE.md)
