# Lands of Lore 2 Classic completion plan

Updated 2026-10-07. Owner: Bob. Integration lead: Codex/Astra.

The main goal is to finish the complete original Lands of Lore 2 Classic in Godot. The first delivery milestone is a playable Act 1 demo, from Draracle's cave through departure to the darker jungle. The demo is an intermediate release of the same game and codebase.

[Classic Edition](classic-edition.md) remains the fidelity contract. Bob’s 2026-10-07 direction permits modern mechanics when better or faster; exact replication is not required. Enhancements and other games do not displace this plan. Existing dated test results certify their recorded revisions only.


Current execution priority after Bob’s modernization direction:

1. Finish automatic Dawn combat using the existing host world update, Godot targeting/collision, saved effect ownership and a small shared tuning profile. Do not wait for native gate, scorer or timer parity. Preserve conversation locks, death, pause and save/return behavior.
2. Opus supplies practical Chain bolt/Plasma lifecycles with reusable effects and clear presentation. Lead integrates attack selection, health and other spell effects. Native comparisons are optional supporting evidence, not blockers.
3. Run an actual hostile encounter and save/reload continuation, then the continuous Act1 campaign. Fix observed blockers, package a reproducible candidate, and work through Bob’s playtest findings.

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

## First action queue

These tasks are planned, not dispatched or acknowledged collaborator assignments. The lead checks existing live ownership before starting them.

| ID | Owner | Action | Required output and dependency |
| --- | --- | --- | --- |
| P01 | Lead | Reconcile the live tree, running tasks and evidence. Preserve current work and saves. | Baseline manifest, active ownership list and reproducible launch/check commands. First action. |
| P02 | Lead | Reconcile the Act 1 checklist against current implementation. | One list of missing observable behaviors, each with source, owner, dependencies and acceptance case. Depends on P01. |
| P03 | Grok | Audit five high-impact provisional rules, beginning with player health versus enemy damage. | Early findings; current implementation, native evidence, uncertainty, gameplay consequence and one discriminating experiment per rule. Can run after P01 alongside P02. |
| P04 | Opus 5.5 | Trace one existing item's pickup, ownership, equipment/use, save/load and area return. | State ownership map, duplicated validation sites and smallest compatible consolidation proposal. Begin with captain reward equipment if P02 confirms it is suitable. |
| P05 | Lead with Opus | Implement and independently verify the selected item contract and encounter pilot. | Shared item identity/validation, explicit state ownership, existing-save compatibility and complete encounter checks. Depends on P03/P04 where behavior is affected. |
| P06 | Lead | Apply the proven pattern to the next highest-priority Act 1 gap. | One playable trigger → result → persistence → return slice, then update coverage. Depends on P02/P05. |
| P07 | Lead and Bob | Produce and evaluate the frozen Act 1 demo candidate. | Fresh campaign receipts, branch checks, export, known-issues sheet, Bob's notes and verified fixes. Depends on required P06 slices. |

Priority inside the content queue: progression/save/crash defects first, shared rule errors second, missing required behaviors third, presentation and optional branches next. Original optional content remains part of final Classic scope.

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
- Original rules, presentation, UI, timing and audio accepted; temporary preview rules resolved.
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
