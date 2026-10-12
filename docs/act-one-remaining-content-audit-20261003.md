# Act One remaining content audit — 2026-10-03

Historical October 3 audit: its ranked Kelsrick, villager, Dawn and world-item gaps have since been implemented. See [current completion status](act-one-completion.md) and the individual encounter documents for evidence and remaining limits.

Scope: read-only reconciliation of the completion plan and actor census with current source contracts and host bindings. No broad regression was repeated. A required content gap means an original observable encounter or item outcome still missing; it does **not** mean a new predicate should block departure. The original outbound predicate remains local55.

The next concrete work after cave guard-control integration is **Jungle Kelsrick64**, followed by **triggered villager62** and **world Dawn63**. These have actual source presence or spawn commands and event chains. They must not be dismissed as staging actors or treated as covered by unrelated room dialogue.

## Implemented since the historical completion notes

| Content | Current binding and evidence | Remaining distinction |
| --- | --- | --- |
| Cave captain56 | `cave_captain.gd`, cave host; plate89/control120 intro, own-region surrender/fight, Spark-mask outcome, aimed use sword/chain. `captain-equipment-transport-checks.json` verifies real grants, gear and four-area disk transport. | Fresh campaign inclusion remains separate from supplied-story fixtures. Fighting death grants sword to **actor**, not automatically player. |
| Scenic guard55 | `cave_scenic_guard.gd` and population, prop574 sequence; `cave-scenic-guard*.json`. | Its B_HUMAN label is not justification to classify all B_HUMAN slots as encounters. |
| Eyes24 | `cave_eyes.gd`, cave host/save. | Source WORM label is not a creature identity. |
| Roach-shaped36/37 | `cave_lurking_roach.gd`, cave host/save/aura/basic targets; native WORM goal5, reach condition44→AA2→attack clip5. `cave-lurking-roach-live-checks.json`. | Visibility/navigation/clock are documented adapters. Marker59 is startup AI context, not a spawn or waypoint list. |
| Museum control96 | `museum_control96.gd`, host/save/assets gates; actual camera geometry admission, original SG17 clips, brick179 and actor30 lifecycle. `museum-control96-live-checks.json`. | Native traversal eligibility is represented by an explicit visibility adapter. This does not establish prop93 treasure admission or general corpse loot. |
| Jungle exit guards58–60 | `jungle_exit_encounter.gd`, `jungle_walkthrough.gd`, quest/save/targets; `jungle-exit-integration-checks.json`. | Old “not wired” notes in `jungle-exit-encounter.md` and `jungle-exit-live.md` are stale. |
| Bacatta61/prop552 | `jungle_bacatta.gd` is instantiated in Jungle host beside exit; source sight/use/hostile/escort/guard60/ending chain. `jungle-bacatta-checks.json`. | This does not by itself bind every BACL4 placement57/65 or L4WW0/66 to a separate required encounter. |
| Equipment | Captain chain8, Mail20 and Bracers5 now feed human defense; save/UI/area transport checked. | Historical “Bracers inventory-only” text in `weapon-shop.md` is stale. Exact native scheduler/stat parity is not a missing item producer. |

The census still lists cave36/37 and Jungle58–61 as unmatched. Conversely, its positive actor56 binding predates the complete captain controller. Neither state should be used as a completion percentage. The immediate-work paragraph of `act-one-completion.md` also predates these additions. Earlier chronological entries saying Roaches are stationary or boulder contact is absent are historical, not current runtime findings.

## Ranked observable gaps

### 1. Kelsrick64: source-present actor and missing normal interaction owner

`game-actors.json` L4_HJ actor64 is definition7 `Kelsrick`, placement archive offset13015266. Direct pinned geometry inspection gives flags0x2582: the absent bit0x1000 is clear. Position is native(-1892,5475,z0), hence Godot(-1892,0,-5475). He is not one of the18 implemented generic villagers39–56.

`game-actor-scripts.json` binds17 actor64 handlers across use/hit/terminal events, groups30402–31196. Normal village admission is region2443/event2/predicate154, stream0 group4354. That group contains `090240001100` at archive13027360 (op9, actor64, property17), plus prop230 operation21 and player/control writes. Existing `jungle_village_dialogue.gd` explicitly owns **control99**, and follow-up dialogue owns **control85**. Neither is an actor64 owner. `jungle-village.md` explicitly preserves the actor64 effect as missing; current gate/follow-up modules contain no actor64 dispatcher.

Smallest implementation: original64 presentation plus source kind4 use chain and exact group4354 interface; saved pose/speech/owner state; add proven hit/death branches without granting loot from placement metadata. Group31170 contains `03024000be4082e104000000` at12759480: definition5 `6-Fine longswd`, granted to actor64. This is an **actor inventory producer**, not evidence for immediate player pickup. Preserve the distinction in the implementation.

### 2. Triggered villager62: unambiguous region admission, currently absent

Actor62 is definition1 TIG_MAL, placement13015154, flags0x7582 (initially absent), native(-713,5307,z0). Three unconditional source region/event2 handlers instantiate the same encounter:

| Region | Stream0 group | Spawn command archive offset |
| --- | --- | --- |
| 1672 | 3384 | 13026368 |
| 1698 | 3408 | 13026392 |
| 1703 | 3432 | 13026416 |

Each begins `09023e000300` (op9 kind2 actor62 property3), then property21 and prop1913 property16. Actor event groups29396–29610 include a speech/timer chain. Example group29396 is actor62 kind6/value276/predicate206 and issues actor property/state, speech and player/actor reposition commands. These are concrete source triggers, not an inferred hostile population.

Smallest next slice: recover that source dialogue resource, instantiate62 only through the three region handlers, run first speech/pose endpoint with saved progress, then bind remaining kind8 audio continuation. Do not append62 to the ordinary39–56 always-present villagers or substitute control85 dialogue.

### 3. World Dawn63: separate from monastery room Dawn

Actor63 definition8 DawnL4 placement13015210, flags0x7582; native(-5710,-3937,z-100). Stream0 region2812/event2/predicate159 group5214 contains `09023f000300` at13028218, an explicit source spawn. Region2842/predicate186 group5246 changes actor animation/state and player position; region2959/group5350 removes63. Actor sight kind5/value0 group29646 (archive12757956 onward) starts original animation; kind4 groups29704/30066/30100 and further terminal/timer/hit groups continue the encounter.

Smallest next slice: decode predicates159/186 and original63 animation-resource sections, bind the actual region spawn→visibility→first use→removal chain with shared quest writes and partial-save recovery. The monastery CAN/MOFF room actors and Hive control75 conversation do not prove this world actor implemented. Which branches are normal versus conditional remains to establish; do not grant on scene entry.

### 4. Reachable world-item admission, then actual supported uses

`prepare_jungle_source_pickups.py` admits only world-item row51 (Th Dagger) out of88. Direct inspection under its pinned archive/geometry contract found additional source rows, all listed here with bit0x1000 clear:

| Row | Source item | Region | Godot position |
| --- | --- | --- | --- |
| 0 | 27-Snare | 3834 | (-1702,0,-4875) |
| 50 | 71-Wax | 3835 | (-1764,0,-5033) |
| 52/53 | 109-Ironwod sap | 3434/3441 | (-2214,70,-4662), (-2123,70,-4647) |
| 54–57 | 82-Vels fruit | 3442/3441/3434 | Original rows in pinned geometry |
| 63–67 | 108-Cave aloe | 3434 | Original rows in pinned geometry |

The same existing adjacency helper reports19 hops from MAGIC region2636 to3834,18 to3835,36 to3434. These are connectivity leads, **not walked reachability** or proof that a row is a free pickup rather than room stock/attached display. Some other rows have suspicious8112 heights; do not instantiate all88 blindly. Current room offers already produce several duplicate item definitions under different provenance identities.

Smallest next slice: local real collision/pickup-admission verification for row0 or the row52–67 shelf near the existing dagger branch; then canonical per-row identity, original art, one-shot collection/consumption history and transport. Reuse Aloe use only after its producer identity and ownership are correct. Do not merge Jungle wax automatically with Hive wax's quest flag or invent exchange dependencies.

### 5. Museum/corpse item outcomes: producer facts exist, pickup admission still separate

`actor-item-grants-checks.json` pins Museum actor20 event9/group12578 allocating two Drag Blood nodes to actor20. Current Museum population has no actor-item-list/pickup consumer. Captain event11/state5 and Kelsrick group31170 likewise grant to actors. These support a bounded actor-inventory and world transfer implementation once the actual drop/collection condition is established.

Do **not** resurrect the old assumption that every placement+52 is a death drop. `audit_act_one_actor_items.py` proves constructor placement+52→runtime+0x74 while runtime item-list+0x78 starts0. Museum32's Thohan identity and skeleton key identities alone are not item possession proof.

Prop93 kind5/value19 group1498 contains the large treasure grant list, but its producer remains unbound. The lead corrected the invented tenth-death prop93=3 outcome: predicate58 reads local23 before the queued increment. This is a specific admission blocker, not authorization to hand out the treasure after ten kills. Keep it visible in the remaining ledger, behind normal known encounters until its producer is established.

## Placements not promoted into mandatory fights

Pinned source placement and literal command census support treating these as staging candidates: cave3–22; Museum0–19; Jungle1–20; Hive0–19. They form regular64-unit grids, have flags0x7182/0x7382 including absent0x1000, and have zero literal addressed actor commands in `game-actor-scripts.json`. This is strong staging evidence, not proof that the native dynamic allocator never uses them. Do not spawn80 invented enemies; implement a dynamic pool only when a concrete producer needs it (the Hive rune-copy pool already has such proof).

Jungle rogues36–38 are absent0x7182 with only groups704/768 property writes and no literal spawn in current streams. They require a producer before becoming encounters. Bacatta57/65 and L4WW0/66 have script references overlapping first/exit story chains; classify them against existing cinematic/control owners before adding bodies. Hive Dawn20 remains an owner-classification question; the existing Hive control75 and monastery content cannot be equated by label alone.

## Required acceptance after new content

Complete the current broad regression, then rerun the fresh continuous route with the new encounters active. Add earned/local branch checks for normal Kelsrick64/villager62/Dawn63 content and admitted item producers; a route can pass while bypassing optional original interactions. Preserve both Museum exits and original quest/departure predicates. Source-bound modern timing/navigation adapters already authorized do not require a new archaeology campaign merely to restate that they are adapters.

Reproduction anchors: `verify_actor_item_grants.source_area('L4_HJ')` pins archive517afe6d… and geometry445d9b27…; stream0/1 owner tables and raw commands above come directly from that helper. Actor records are56 bytes at geometry u32(0x1c); world items37 bytes at u32(0x20), count u32(0x6c). Item names resolve through the existing GLOBAL definitions3984507021 loader. No source archives or current runtime files were edited for this audit.
