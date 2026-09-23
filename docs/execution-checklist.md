# LoL2 execution checklist

Updated 2026-09-23. Owner order: **all maps → complete Act1 → Act2**.

This is the persistent execution backlog requested by Bob. Checked items mean the stated bounded task is verified, not that the entire map/game is complete. All15 maps currently remain `ready_for_content=false`. Work in dependency order; retain source evidence and label modern approximations. Unresolved native details warrant additional research only when they prevent a concrete implementation decision.

Evidence: `/home/bob/AI_COMMS/map_first_20260922/integrated_checkpoint.json`. Existing detailed content dependencies remain in `act-one-completion.md`, `game-coverage.md`, and the canonical task queue. Act2 archive membership is deliberately unassigned until supported by progression evidence.

## Map foundation — established evidence

- [x] T001 — Build all15 archive maps with source identities and texture bindings.
- [x] T002 — Preserve initial props, mechanisms, attached sprites and later-state assets.
- [x] T003 — Resolve initial scenery/material-layout gaps.
- [x] T004 — Validate all23 video atlases against independent decoding.
- [x] T005 — Fix mechanism cutout metadata and reload all15 saved scenes.
- [x] T006 — Retain optional emulated boundaries with explicit provenance.
- [x] T007 — Inventory237 topology groups and render920 component views.
- [x] T008 — Audit primary floors, floor subdivisions and ceiling admission.
- [x] T009 — Export structural collision for all15 maps.
- [x] T010 — Run230 representative downward collision probes with zero misses.
- [x] T011 — Run exhaustive floor/ceiling triangle probes and preserve3 exact misses.
- [x] T012 — Prepare five captured surface-state variants without replacing initial source maps.

## Map foundation — remaining implementation and acceptance

- [ ] T013 — Classify the3 near-collinear collision misses using local movement tests; preserve raw results.
- [x] T014 — Add a reusable all-map capsule placement/movement diagnostic with explicit assumed dimensions.
- [ ] T015 — Check all source arrivals for floor support, clearance and safe placement.
- [ ] T016 — Separate form-dependent, scripted and invalid arrival placements; do not move arrivals silently.
- [ ] T017 — Verify walkable seams between adjoining floors and slopes.
- [ ] T018 — Check stairs, ledges, narrow passages and low ceilings with appropriate forms.
- [ ] T019 — Check subdivision tiling for cracks, overlaps and parent/child duplication.
- [ ] T020 — Check wall winding, openings and boundary spans against source admission.
- [ ] T021 — Determine runtime admission of isolated sectors or record an accepted emulation policy.
- [ ] T022 — Bind named interiors/subareas to source regions using evidence.
- [ ] T023 — Obtain original reference views for L12_CM,L13_RC,L14_HT,L17_HC,L19_BC.
- [ ] T024 — Verify representative UV alignment on walls, floors, ceilings and slopes.
- [ ] T025 — Implement or explicitly settle panorama heading/pitch behavior beyond the two fixed-pose samples.
- [ ] T026 — Resolve captured palette changes separately from lighting differences.
- [ ] T027 — Verify indexed shade/remap behavior across representative indoor/outdoor scenes.
- [ ] T028 — Verify animated texture frame order and observable playback rates.
- [ ] T029 — Verify billboard orientation, cutouts and placement heights across maps.
- [ ] T030 — Verify initial mechanism geometry and moving-part pivots.
- [ ] T031 — Catalog alternate geometry/material states needed for later content.
- [x] T032 — Verify each saved surface variant uses correct geometry and texture resources.
- [x] T033 — Add collision to variants that will be used as playable foundations.
- [ ] T034 — Verify map unload/reload releases texture resources; investigate known GPU shutdown leaks.
- [ ] T035 — Measure scene load time, movement performance and memory on the actual machine.
- [ ] T036 — Build a reproducible local map bundle from user-provided original files.
- [ ] T037 — Produce per-map review notes, exact open defects and a playable review entry point.
- [ ] T038 — Complete all-map geometry/texture acceptance before opening content integration.

## Act1 — scope and progression (starts after maps)

- [ ] T039 — Retain confirmed endpoint: leaving Huline Jungle for the darker jungle.
- [ ] T040 — Inventory mandatory and optional Act1 quests from original event dependencies.
- [ ] T041 — Bind display names and required first-sphere connected areas.
- [ ] T042 — Trace required item acquisition, consumption and quest flags.
- [ ] T043 — Trace form changes and human/beast/lizard route gates.
- [ ] T044 — Bind entrance, departure and revisit conditions to source event owners.
- [ ] T045 — Create a continuous route checklist with original prerequisites and recovery paths.
- [ ] T046 — Choose a bounded modern implementation for unresolved behavior when evidence permits.

## Act1 — shared runtime

- [ ] T047 — Integrate actor activation and deactivation into loaded map ownership.
- [ ] T048 — Bind AI perception, live targets and action scheduling.
- [ ] T049 — Connect attack timing and animation frame events to live outcomes.
- [ ] T050 — Connect player hit selection, obstruction and reach.
- [ ] T051 — Integrate damage, mitigation, health, statuses and death.
- [ ] T052 — Implement required loot, rewards and actor removal.
- [ ] T053 — Connect inventory, equipment and required item interactions.
- [ ] T054 — Connect switches, doors, lifts, movable geometry and puzzle state.
- [ ] T055 — Connect region material/height changes and refresh dependent collision.
- [ ] T056 — Connect dialogue conditions, choices, voice playback and subtitles.
- [ ] T057 — Connect original cutscene entry/exit and player-control ownership.
- [ ] T058 — Persist timers, RNG, actors, inventory, puzzles and map-state changes.
- [ ] T059 — Verify death/retry, interrupted dialogue and partially completed interactions.
- [ ] T060 — Preserve existing working routes and avoid replacing proven components unnecessarily.

## Act1 — Draracle cave

- [ ] T061 — Integrate required cave encounters into the continuous route.
- [ ] T062 — Complete required cave puzzles and item dependencies.
- [ ] T063 — Verify bridge progression and alternative/form-dependent passages.
- [ ] T064 — Complete required discussions, scenes and voice/text synchronization.
- [ ] T065 — Verify museum handoff with persistent inventory and quest state.
- [ ] T066 — Test cave save/load at partial puzzle and encounter states.

## Act1 — Museum

- [ ] T067 — Complete gallery and exhibit dependencies.
- [ ] T068 — Verify all required pickups, equipment and Atlas behavior.
- [ ] T069 — Complete escape conditions and dialogue.
- [ ] T070 — Preserve both established jungle exits and recovery behavior.
- [ ] T071 — Verify mirror/dragon paths against original conditions.
- [ ] T072 — Test interrupted scenes, timeouts, saves and return visits.

## Act1 — Huline Jungle and connected areas

- [ ] T073 — Populate original actors and required interactable items.
- [ ] T074 — Implement quests in verified prerequisite order.
- [ ] T075 — Integrate required village/interior/connected-area conversations.
- [ ] T076 — Complete human and small-form Hive entrances.
- [ ] T077 — Complete Hive room traversal, guardian/pillar dependencies and return route.
- [ ] T078 — Integrate executioner activation, combat and original outcomes.
- [ ] T079 — Bind executioner clock/state initialization versus restored-save state.
- [ ] T080 — Persist Hive encounter progress through jungle transitions.
- [ ] T081 — Implement other required connected-area encounters and puzzles.
- [ ] T082 — Implement valid departure conditions to the darker jungle.
- [ ] T083 — Verify destination arrival and transferred campaign state.

## Act1 — end-to-end acceptance

- [ ] T084 — Complete new-game-to-departure playthrough without debug jumps.
- [ ] T085 — Verify required form abilities on the continuous route.
- [ ] T086 — Verify save/load before and after each major quest transition.
- [ ] T087 — Verify death and retry without lost or duplicated critical items.
- [ ] T088 — Verify return visits preserve completed actors, doors and puzzles.
- [ ] T089 — Check original interface, speech, effects and music for this route.
- [ ] T090 — Run relevant core, scene, transition and save regressions.
- [ ] T091 — Prepare a reproducible Act1 review build and known-issues notes.
- [ ] T092 — Resolve Bob playtest findings; record acceptance separately from automated checks.

## Act2 — opens after Act1 integration and verification

- [ ] T093 — Bind Act2 boundaries from original progression before assigning archives to it.
- [ ] T094 — Inventory required/optional areas, quests, actors and conversations.
- [ ] T095 — Identify required incoming Act1 flags, items and form abilities.
- [ ] T096 — Implement first arrival and safe save/restore.
- [ ] T097 — Populate one complete area at a time using shared runtime systems.
- [ ] T098 — Implement verified quest and encounter dependencies.
- [ ] T099 — Integrate altered map states, revisits and outbound transitions.
- [ ] T100 — Verify inventory/quest persistence across Act1→Act2 transitions.
- [ ] T101 — Complete Act2 route without debug jumps.
- [ ] T102 — Run recovery, save, presentation and performance checks.
- [ ] T103 — Prepare Act2 review build and resolve playtest findings.

## Collaboration and publication

- [ ] T104 — Resume bounded Grok tasks when its usage becomes available; verify every change.
- [ ] T105 — Resume bounded Claude advice when its usage becomes available; verify findings.
- [ ] T106 — Prepare a code/documentation collaboration packet for the potential LoL1 contributor.
- [ ] T107 — Compare a shared extraction case if the contributor supplies code or findings.
- [ ] T108 — Keep ownership and AI task assignments explicit to avoid conflicting edits.
- [ ] T109 — Publish focused tested code/docs through isolated worktrees.
- [ ] T110 — Keep original assets and personal saves out of public commits.
- [ ] T111 — Update this checklist and canonical status with evidence as work completes.

## Per-map completion gates

Apply these gates to every archive; a reference sample or successful export alone does not close them. Repeated gates are separate map deliverables.

### L1_DC — Draracle's cave

- [ ] T112 — Bind named subareas and record which components they occupy.
- [ ] T113 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T114 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T115 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T116 — Catalog required initial and later geometry/material states.
- [ ] T117 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T118 — Record geometry/texture review evidence and readiness decision.

### L3_DH — Museum / Draracle's halls

- [ ] T119 — Bind named subareas and record which components they occupy.
- [ ] T120 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T121 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T122 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T123 — Catalog required initial and later geometry/material states.
- [ ] T124 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T125 — Record geometry/texture review evidence and readiness decision.

### L4_HJ — Huline Jungle

- [ ] T126 — Bind named subareas and record which components they occupy.
- [ ] T127 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T128 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T129 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T130 — Catalog required initial and later geometry/material states.
- [ ] T131 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T132 — Record geometry/texture review evidence and readiness decision.

### L5_HC — Hive Caves

- [ ] T133 — Bind named subareas and record which components they occupy.
- [ ] T134 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T135 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T136 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T137 — Catalog required initial and later geometry/material states.
- [ ] T138 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T139 — Record geometry/texture review evidence and readiness decision.

### L7_DH — L7_DH — display name to bind

- [ ] T140 — Bind named subareas and record which components they occupy.
- [ ] T141 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T142 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T143 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T144 — Catalog required initial and later geometry/material states.
- [ ] T145 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T146 — Record geometry/texture review evidence and readiness decision.

### L8_SJ — L8_SJ — display name to bind

- [ ] T147 — Bind named subareas and record which components they occupy.
- [ ] T148 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T149 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T150 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T151 — Catalog required initial and later geometry/material states.
- [ ] T152 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T153 — Record geometry/texture review evidence and readiness decision.

### L9_DR — L9_DR — display name to bind

- [ ] T154 — Bind named subareas and record which components they occupy.
- [ ] T155 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T156 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T157 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T158 — Catalog required initial and later geometry/material states.
- [ ] T159 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T160 — Record geometry/texture review evidence and readiness decision.

### L10_DC — L10_DC — display name to bind

- [ ] T161 — Bind named subareas and record which components they occupy.
- [ ] T162 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T163 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T164 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T165 — Catalog required initial and later geometry/material states.
- [ ] T166 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T167 — Record geometry/texture review evidence and readiness decision.

### L12_CM — L12_CM — display name to bind

- [ ] T168 — Bind named subareas and record which components they occupy.
- [ ] T169 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T170 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T171 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T172 — Catalog required initial and later geometry/material states.
- [ ] T173 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T174 — Record geometry/texture review evidence and readiness decision.

### L13_RC — L13_RC — display name to bind

- [ ] T175 — Bind named subareas and record which components they occupy.
- [ ] T176 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T177 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T178 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T179 — Catalog required initial and later geometry/material states.
- [ ] T180 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T181 — Record geometry/texture review evidence and readiness decision.

### L14_HT — L14_HT — display name to bind

- [ ] T182 — Bind named subareas and record which components they occupy.
- [ ] T183 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T184 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T185 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T186 — Catalog required initial and later geometry/material states.
- [ ] T187 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T188 — Record geometry/texture review evidence and readiness decision.

### L16_CA — L16_CA — display name to bind

- [ ] T189 — Bind named subareas and record which components they occupy.
- [ ] T190 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T191 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T192 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T193 — Catalog required initial and later geometry/material states.
- [ ] T194 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T195 — Record geometry/texture review evidence and readiness decision.

### L17_HC — L17_HC — display name to bind

- [ ] T196 — Bind named subareas and record which components they occupy.
- [ ] T197 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T198 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T199 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T200 — Catalog required initial and later geometry/material states.
- [ ] T201 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T202 — Record geometry/texture review evidence and readiness decision.

### L19_BC — L19_BC — display name to bind

- [ ] T203 — Bind named subareas and record which components they occupy.
- [ ] T204 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T205 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T206 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T207 — Catalog required initial and later geometry/material states.
- [ ] T208 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T209 — Record geometry/texture review evidence and readiness decision.

### L20_BB — L20_BB — display name to bind

- [ ] T210 — Bind named subareas and record which components they occupy.
- [ ] T211 — Verify floors, ceilings, slopes, walls and openings across accessible subareas.
- [ ] T212 — Verify textures, UVs, palettes, transparency, animation and panorama where present.
- [ ] T213 — Check arrival placement and representative capsule routes, including form restrictions.
- [ ] T214 — Catalog required initial and later geometry/material states.
- [ ] T215 — Resolve visual defects or document an explicit accepted emulation with its limits.
- [ ] T216 — Record geometry/texture review evidence and readiness decision.

## Current next action

Arrival diagnostic implemented: all71 supported,69 clear for the assumed radius8/height64 capsule,2 overlapping. L8 selector0 clears with12-unit diagnostic lift;L20 selector2 clears at radius6. No alternatives adopted and no arrivals modified. Next: classify these arrival exceptions and check subdivision surface coverage. T015 remains open until safe placement is established, not merely sampled.

## Latest verified execution

- T014: all71 arrivals examined;69 clear under assumed review capsule dimensions;two overlaps retained. Source positions unchanged.
- T019 partial:61 subdivision groups form single closed projected outlines;no overlapping child triangles;31 source parent/child outline differences retained. Height continuity and wall joins still need checks. Six portable tests pass.
- T032/T033: five saved-state variants now have structural collision;64,901 floor/ceiling probes pass with zero misses;allfive saved-scene reloads pass.
- T013 partial: allthree known thin-triangle misses reproduce at original coordinates and hit after translating the same vertices near the origin. Positive and negative controls pass. This isolates coordinate precision;movement/traversal acceptance remains open.
