# Act 2 E interaction survey — BJ14 F1/F2/F6 on 2f8bc88

Source census inherited from the earlier 75f8160 survey. All game scripts are byte-identical between 75f8160 and requested base 2f8bc88 (the intervening merge is tooling/documentation); no new wide runtime survey is claimed.

Scope: L8 Savage Jungle, L9 Ruins, L10 Cemetery, L12 Claw Mountains, L13 Citadel, L14 Temple. Source plus live scene attachment inventory; this is not a physical walk to every placement. All56 E-handler families (67 scene attachments) are accounted for. Targeted real-input walks qualify the changed prompt families separately.

| Map | E controller attachments | Act2 pickups | Native E movables | Bound controls |
| --- | ---: | ---: | ---: | ---: |
| L10_DC | 11 | 58 | 3 | 1 |
| L12_CM | 6 | 28 | 2 | 1 |
| L13_RC | 9 | 83 | 0 | 0 |
| L14_HT | 23 | 66 | 11 | 1 |
| L8_SJ | 13 | 33 | 4 | 1 |
| L9_DR | 5 | 57 | 3 | 2 |

The shared L8 controller also hosts13 eggs/Manafoil rows, with one owner per Act2 twin. The full object inventory lists325 Act2 placements,13 shared rows,23 native movables and six bound controls. Dedicated puzzle target arrays/sets are covered by their families and unchanged reach/aim/state gates.

| E handler family | Maps | Prompt coverage |
| --- | --- | --- |
| [act2_chargers](../scripts/lol2/act2_chargers.gd) | L10_DC, L9_DR | existing contextual Label: E — Retrieve charged globe; E — Place an empty glass globe |
| [act2_progression](../scripts/lol2/act2_progression.gd) | L10_DC, L12_CM, L13_RC, L14_HT, L8_SJ, L9_DR | F2 adds E — Touch the winged statue for L10 control150 only; other binder E hooks remain without prompts (see below) |
| [act2_world_items](../scripts/lol2/act2_world_items.gd) | L10_DC, L12_CM, L13_RC, L14_HT, L8_SJ, L9_DR | F1 adds E — Take &lt;item&gt;; unreleased bracers show The bracers are shielded. |
| [area_world_items](../scripts/lol2/area_world_items.gd) | L8_SJ | existing shared HUD prompt: E — Take  |
| [l10_barrel](../scripts/lol2/l10_barrel.gd) | L10_DC | existing contextual Label: E — Flip switch; E — Tip barrel toward the north tomb |
| [l10_braziers](../scripts/lol2/l10_braziers.gd) | L10_DC | existing contextual Label: E — Light brazier |
| [l10_emperor](../scripts/lol2/l10_emperor.gd) | L10_DC | existing contextual Label: E — Speak with the Emperor; E — Use the ankh; E — Place or retrieve the matching globe |
| [l10_emperor_entry](../scripts/lol2/l10_emperor_entry.gd) | L10_DC | F2 adds E — Use the ankh on the slab / The slab has an ankh-shaped hollow. / E — Retrieve the ankh |
| [l10_main_gate](../scripts/lol2/l10_main_gate.gd) | L10_DC | existing contextual Label: E — Unlock with the Dracoid Sigil |
| [l10_priest](../scripts/lol2/l10_priest.gd) | L10_DC | existing contextual Label: E — Speak with the priest |
| [l10_silverleaf](../scripts/lol2/l10_silverleaf.gd) | L10_DC | existing contextual Label: E — Pick Silverleaf |
| [l10_tombs](../scripts/lol2/l10_tombs.gd) | L10_DC | existing contextual Label: E — Offer a matching charged globe |
| [l12_citadel](../scripts/lol2/l12_citadel.gd) | L12_CM | existing contextual Label: E — Search Kenneth; E — Speak with Baccata |
| [l12_crevasse](../scripts/lol2/l12_crevasse.gd) | L12_CM | existing contextual Label: E — Change to Lizard for the crevasse; E — Return to Human |
| [l12_frozen_bow](../scripts/lol2/l12_frozen_bow.gd) | L12_CM | existing contextual Label: E — Catch the blue bow |
| [l12_niche_armor](../scripts/lol2/l12_niche_armor.gd) | L12_CM | existing contextual Label: E — Take and wear obsidian chain mail |
| [l13_altar](../scripts/lol2/l13_altar.gd) | L13_RC | existing contextual Label: E — Enchant equipped sword; E — Take Dreamstone |
| [l13_belial](../scripts/lol2/l13_belial.gd) | L13_RC | existing contextual Label: E — Enter the web doorway |
| [l13_dawn_prison](../scripts/lol2/l13_dawn_prison.gd) | L13_RC | existing room E help; exterior entry is automatic, not E: E — Examine recess   Enter — Skip speech   Esc — Leave |
| [l13_eggs](../scripts/lol2/l13_eggs.gd) | L13_RC | existing contextual Label: E — Use eye switch |
| [l13_elevator](../scripts/lol2/l13_elevator.gd) | L13_RC | existing contextual Label: E — Call elevator; E — Use elevator brain |
| [l13_exit_lock](../scripts/lol2/l13_exit_lock.gd) | L13_RC | existing contextual Label: E — Retrieve Dreamstone; E — Place Dreamstone |
| [l13_prison](../scripts/lol2/l13_prison.gd) | L13_RC | existing room E help; exterior entry is automatic, not E: E — Use switch   Enter — Skip speech   Esc — Leave |
| [l14_bedroom](../scripts/lol2/l14_bedroom.gd) | L14_HT | existing contextual Label: E — Push headboard |
| [l14_belial](../scripts/lol2/l14_belial.gd) | L14_HT | existing contextual Label:     E — Confront the Hive Lord |
| [l14_chamber_voices](../scripts/lol2/l14_chamber_voices.gd) | L14_HT | existing contextual Label: E — Enter the Chamber of Voices |
| [l14_fire_paths](../scripts/lol2/l14_fire_paths.gd) | L14_HT | existing contextual Label: E — Press path button |
| [l14_flute_slot](../scripts/lol2/l14_flute_slot.gd) | L14_HT | existing contextual Label: E — Retrieve flute; E — Place flute |
| [l14_hanging](../scripts/lol2/l14_hanging.gd) | L14_HT | existing contextual Label: E — Draw aside left wall hanging |
| [l14_hopper_platform](../scripts/lol2/l14_hopper_platform.gd) | L14_HT | existing contextual Label: E — Raise platform to gallery; E — Carry hopper corpse; E — Place hopper corpse on platform |
| [l14_idol_pedestals](../scripts/lol2/l14_idol_pedestals.gd) | L14_HT | existing contextual Label: E — Place Jkar idol |
| [l14_library](../scripts/lol2/l14_library.gd) | L14_HT | existing contextual Label: E — Press hall button |
| [l14_machines](../scripts/lol2/l14_machines.gd) | L14_HT | existing contextual Label: E — Press the pedestal button; E — Carry filled trough; E — Insert trough; G — Turn long edge first |
| [l14_niche](../scripts/lol2/l14_niche.gd) | L14_HT | existing contextual Label: E — Set machine statue in empty niche |
| [l14_post_shard](../scripts/lol2/l14_post_shard.gd) | L14_HT | existing contextual Label: E — Take green crystal shard |
| [l14_priest_body](../scripts/lol2/l14_priest_body.gd) | L14_HT | existing contextual Label: E — Carry priest's body; E — Place body on stone rectangle |
| [l14_priest_ritual](../scripts/lol2/l14_priest_ritual.gd) | L14_HT | existing contextual Label: E — Offer poison; E — Offer aloe |
| [l14_quill](../scripts/lol2/l14_quill.gd) | L14_HT | still no prompt; outside the revised F1/F2/F6 plan |
| [l14_shard_bowls](../scripts/lol2/l14_shard_bowls.gd) | L14_HT | existing contextual Label: E — Place green shard in suspended bowl |
| [l14_spider_burrow](../scripts/lol2/l14_spider_burrow.gd) | L14_HT | still no prompt; outside the revised F1/F2/F6 plan |
| [l14_spiral](../scripts/lol2/l14_spiral.gd) | L14_HT | existing contextual Label: E — Retrieve Dreamstone; E — Place Dreamstone |
| [l14_tilt](../scripts/lol2/l14_tilt.gd) | L14_HT | existing contextual Label: E — Press high button |
| [l14_trap_route](../scripts/lol2/l14_trap_route.gd) | L14_HT | existing contextual Label: E — Open side door |
| [l14_trials](../scripts/lol2/l14_trials.gd) | L14_HT | existing contextual Label: E — Take statue; E — Open trial door |
| [l8_baccata](../scripts/lol2/l8_baccata.gd) | L8_SJ | existing contextual Label: E — Cut Baccata down; E — Speak with Baccata |
| [l8_cache_ladder](../scripts/lol2/l8_cache_ladder.gd) | L8_SJ | existing shared HUD prompt: E — Climb down; E — Climb the ladder |
| [l8_clubhouse](../scripts/lol2/l8_clubhouse.gd) | L8_SJ | existing contextual Label: E — Speak to the clubhouse guard |
| [l8_dawn](../scripts/lol2/l8_dawn.gd) | L8_SJ | existing contextual Label: E — Give Dawn the Bracers of the Dead |
| [l8_huline_speech](../scripts/lol2/l8_huline_speech.gd) | L8_SJ | existing contextual Label: E — Listen |
| [l8_journey](../scripts/lol2/l8_journey.gd) | L8_SJ | existing contextual Label: E — Speak with the village guard; E —  |
| [l8_temple_door](../scripts/lol2/l8_temple_door.gd) | L8_SJ | existing contextual Label: E — Retrieve Dreamstone; E — Enter Temple; E — Place Dreamstone |
| [l8_tree](../scripts/lol2/l8_tree.gd) | L8_SJ | existing contextual Label: E — Retrieve crystal shard; E — Place crystal shard |
| [l8_tree_bridge](../scripts/lol2/l8_tree_bridge.gd) | L8_SJ | existing shared HUD prompt: E — Chop the tree |
| [l8_tribe](../scripts/lol2/l8_tribe.gd) | L8_SJ | existing contextual Label: Initiation stamina — You %d   Daniel %d   Left click — spar   E — yield; E — Return to the village |
| [l9_pyre](../scripts/lol2/l9_pyre.gd) | L9_DR | existing contextual Label: E — Drag the body; E — Lay the body on the pyre; E — Take filled urn |
| [l9_statue](../scripts/lol2/l9_statue.gd) | L9_DR | existing contextual Label: E — Offer the Emperor's remains     Esc — Leave; E — Examine the statue alcove |

## Revised owner scope

F1 covers world pickups, including the shielded-bracer explanation. F2 covers control150 and the ankh slab, including physical statue contact using its existing native caller. F6 discovers the exact owner-approved fence, rail and floating-table notes once through the existing saved Journal list. These puzzle answers are not inline prompts. Controls help names C crouch and Ctrl tuck. The shared HUD now refreshes Character text only on the Character page, so the open Journal keeps its notes instead of being overwritten each frame. F3/F4/F5/F7 belong to the lead and are unchanged here.

The broader e1418bc proposal is superseded, not a dependency. Its generic mechanism, quill and burrow prompts are deliberately not carried into these three scoped commits. Missing prompts that remain outside the revised plan:

| Map | Remaining source-owned E hooks without their own prompt |
| --- | --- |
| L8 | native movables53/54 and prop1198 (clubhouse51/52 already have their owner prompt) |
| L9 | native movables58/59/115 and control82 when manually admitted; prop104 is timer-only |
| L10 | native movables87/88/89 |
| L12 | native movables52/53 and control74 |
| L13 | none additional in the attached E-owner survey |
| L14 | native movables54/65/66/67/72/76/83/84/85/86/87 and prop170; quill and spider-burrow action |

These are a source census, not proof that every hook is active in every quest state. Automatic Citadel-room exterior entry remains separate from E interaction. A timer-only row has no manual action to prompt.

## Acceptance and limits

Registry1316–1326 contains eleven rendered local real-input cases. They use unchanged hash-pinned staged chain checkpoints, with upstream handler-driven provenance explicitly disclosed. Local segments keep full scene physics and use W/mouse/E/clicks/Space/Ctrl/J/F5/F9. Fitting stays as hosted: L10 adapter on; L9 legacy host does not attach it. The slab test obtains its ankh through real priest E input and archives that real F5 save before approaching the slab. This is local acceptance, not a fresh unaided campaign claim.

The fast source audit declares zero teleport sites and three test-aid sites per new entry: two clock overrides and the conservatively counted read-only until.call callback. They are audited source-site counts, not per-run executions. No local direct pose/resource/gameplay-action writes are used.

A synthetic Escape dispatched from a physics callback during inventory unpause emitted five engine self_list errors on unchanged base as well as candidate. Exact baseline process-frame delivery passes; the event helper now delivers discrete keys from process_frame. Earlier failed diagnostics are preserved separately. This is a test-driver correction, with no gameplay/engine patch.

Generic native local11 is still not rewound by same-scene F9 (independent unchanged-base witness in sol_lane/act2_prompts_20261110/native_reload_baseline). Statue E and contact use independent fresh scenes; pre-contact F5/F9 is checked. No new native-save fidelity claim.

Evidence: AI_COMMS/sol_lane/bj14_f1_f2_f6_20261110, including fixture pins, exact source-site audit, baseline comparison, targeted reports and inspected screenshots. Final status belongs to HANDOFF.md/READY.json, not this census.
