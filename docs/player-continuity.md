# Player continuity check (Cave → Museum → Jungle)

`scripts/lol2/player_continuity.gd` is the smallest reusable check for the cross-location contract in
[classic-completion-plan.md](classic-completion-plan.md). It adds no new state owner and changes no transport; it only
reads the existing adapters.

## What it reads

| Host / input | Source |
| --- | --- |
| Cave | `_completion_state()` (the packet the cave hands the Museum) |
| Museum | `inventory_state()` (the packet the Museum hands the Jungle) |
| Jungle | `inventory_state()` plus quest-owned `player_magic_reward_state` / `player_reward_state` |
| Hive | `hive_packet()`: the player part of `area_handoff()` read from the same owners without calling it (`carried_inventory` + `player_form` + `curse.snapshot()` + `Warriors.health` if > 0; quest-owned magic/fighting from the live checkpoints, else the carried quests) |
| Saves/handoffs | `from_save()`: Museum `checkpoint` saves, `{inventory, quests}` saves, bare packets |

Observation is read-only. `area_handoff()` is not called, because it refreshes `hive_curse.checkpoint.enabled` from
the curse admission while packing. When that flag is stale (admission changed by command 24/25 while the curse loop
was not ticking), observing through it would change canonical Hive state.
`tests/player_continuity_readonly_test.gd` covers this. With the tree paused, it uses the fresh Hive and the four R16
Hive saves, each consistent and stale in two ways. The Hive owners must stay byte-identical, and the fields must equal
`from_packet(area_handoff())` and the diagnostics.

Inventory-packet fields win over quest-owned fields, which is the precedence the Jungle/Hive loaders use. The Jungle
moves magic/fighting into quests, so reading only its inventory dictionary would wrongly report them lost.

## Snapshot fields

`health`, `player_form`, `equipped_item`, `equipped_armor`, `collected[<id>]` (count per carried item ID),
`curse.phase`, `curse.cave_triggered`, `spent[<id>]` (count per consumed item ID), `item_effects.ancient_charges`/`offhand`/
`dampened`, `item_effects.aloe.pending`/`base`, `item_effects.fire_crystals[<id>]`, `magic.level`/`experience`/`mana`/
`maximum`/`spell`, `fighting.level`/`experience`/`maximum`/`health`/`condition`/`stat151`/`stat155`.

Positions, cooldowns, curse timers, remaining effect fields and per-area world/quest state are not compared by this
projection. This omission is not permission to reset them. Separate owner/transport tests cover some of those fields;
the Hive return check below compares the complete magic checkpoint, including cooldown.

## Comparison rules

`compare(before, after, allowed)` returns every difference that `allowed` does not explain:

- a field present before and absent after is reported (`missing after`) unless its removal is explicitly allowed;
- a field that appears without permission is reported;
- `allowed[field]` is the exact value the field must have afterwards, `null` for a deliberate removal, or
  `{"min", "max", "reason"}` for documented elapsed-time drift (mana regeneration);
- an expected field missing from both snapshots is reported too;
- numeric bounds and results must be finite, bounds ordered, and a nonempty reason supplied;
- carried/consumed IDs retain multiplicity, while list order is irrelevant.

`mana_allowance` caps regeneration using measured simulated time, carried regeneration remainder and the production
regeneration period. The travel test includes two frame endpoints as a conservative timing margin. Pause can reduce
regeneration within the bound; an arbitrary refill to maximum is not automatically permitted.

The projection preserves whether `magic.spell` was actually present. It does not synthesize Spark for a missing key;
legacy migration/defaults remain the loaders' responsibility. Otherwise losing an explicit Spark selection could be
invisible to comparison. Inventory-owned and quest-owned magic both have missing/appearing/expected-field controls.

Post-R14 review: the new omission controls failed against R14's checker, then all four focused contract/HUD/chain/
new-process checks passed with stable source after the correction (including the two R13 compatibility saves).
Local evidence: `AI_COMMS/classic_review_20261007/lead/continuity_spell_review_20261012`.
This changes verification only; the verified R14 binary is unchanged.

`player_continuity_contract_test` checks these rules with missing-field, duplicate-item, NaN/infinity, malformed-range
and excessive-refill negative controls.

## Tests

**`tests/player_continuity_chain_test.gd`** (rendered, `--demo-interface`): travel phase.

- Earned through ordinary game paths with real viewport clicks/keys:
  - fighting XP: Attack Button hits on a cave roach (`cave_melee_reward`);
  - magic XP: a Spark loaded from the Spell Bar and cast with the Magic Button on that roach (`award_hit`);
  - consumed item: inventory row + "Use Aloe" (spent history; the heal runs during play until it is used up);
  - equipment: inventory row + "Equip" (Stalagmite on the Attack ring);
  - mana and selected spell: Spell Bar Heal + Magic Button cast;
  - Museum → Jungle: the E key at the Shining Path approach (production `enter_mirror`).
- Supplied, labelled in the receipt:
  - two Aloe and one Stalagmite placed in the cave owners (their world pickups are not walked);
  - the player placed and aimed beside the roach, then put back where it stood, and placed at the mirror approach;
  - health 14 before the cave Heal;
  - the chamber movie skipped (`chamber_arrival_state = "complete"`, then the production `_enter_museum` transfer);
  - the Museum introduction skipped.
- Checks:
  - Cave → Museum: no difference except bounded mana regeneration;
  - one explicit Museum change (Heal: health +6, mana −2);
  - Museum → Jungle: no difference except bounded mana regeneration;
  - the HUD Character page, Attack ring and Magic ring agree with the state in each area (screenshots);
  - each area is saved with the HUD Save button;
  - no fall recovery (`resets`) ran during the cave stage.
- Negative controls on live Jungle state, each of which must fail with exactly the expected message:
  - one Aloe dropped from `carried_collected`;
  - one fighting XP removed;
  - the fighting packet removed from a handoff snapshot (7 missing fields).

  Restoring the state gives an empty diff.

**`tests/player_continuity_restart_test.gd`** (rendered): runs in a new process after the travel phase.

- Each area scene starts fresh and the HUD Load button loads that area's save (sha256 checked against the travel
  receipt). The live state must equal the save-time snapshot with no allowed changes and must differ from a fresh
  start. The HUD must agree.
- With `LOL2_EARNED_SAVES=<dir>`, the R13 campaign saves `act1_magic_museum_arrival.json` and
  `act1_broken_museum_jungle.json` load through the HUD with no semantic difference from the file.

Receipts: `user://tests/continuity/phase1.json` and `phase2.json`, the per-area saves, and screenshots.

**`tests/player_continuity_hive_return_test.gd`**, then **`tests/player_continuity_hive_restart_test.gd`** in a new
process (rendered, `--demo-interface`, `LOL2_EARNED_SAVES`): matrix case 2, Jungle → Hive → Jungle.

- **Start:** the R13 earned Jungle save `act1_broken_museum_jungle.json`, loaded with the HUD Load button. It carries
  fighting 338 XP, magic 185 XP, health 15 and the Fine Longsword.
- **Real clicks:** a Heal in the Jungle and a Heal in the Hive.
- **Travel:** the production `HiveRoute`. The player is placed inside each verified trigger polygon (supplied), and
  physics triggers the route.
- **Supplied:** Hive health is lowered by 6 before its Heal.
- **Checks:**
  - Both crossings show no difference beyond time-bounded mana regeneration.
  - The HUD agrees in each area.
  - The Hive and Jungle saves made with the HUD Save button reload in a new process with zero difference.
  - Dropping one carried item or one fighting XP from live Hive state fails the comparison.

**`tests/player_continuity_room_test.gd`**, then **`tests/player_continuity_room_restart_test.gd`** in a new process:
matrix case 3, Jungle → village room overlays → Jungle.

- **Start:** the same R13 earned Jungle save, loaded with the HUD Load button.
- **Ordinary input** (as `tavern_liz_ordinary_route_test`): production `move_grounded` walks the follow-up arm and into
  region 3501 (VILLAGE). Real viewport clicks then open CAN (Escape farewell) and LIZ, and take one beehive wax;
  Escape twice returns to the world.
- **Supplied:** S1 (the main village gate open) and S2 (the start point).
- **Checks:**
  - Player snapshots are taken at VILLAGE entry, after CAN, after the wax and back in the world.
  - Each differs from the start only by the one wax item and time-bounded regeneration.
  - The HUD agrees.
  - The world save made with the HUD Save button reloads in a new process with zero difference.

## Evidence classes (do not mix)

- **Component (injected state):** `classic_hud_acceptance_test` supplies health/mana/weapon/form values and checks the
  HUD and save round trip. `player_magic_handoff_test`, `cave_fighting_handoff_test` and
  `captain_equipment_transport_test` inject packets.
- **Ordinary-input route, partial:** the continuity chain earns XP, item use, equipment and spell state with real
  clicks and production transfers, and it walks the Museum → Jungle mirror by key. Its pickups, positioning and both
  movies are supplied, so it is **not** an unassisted playthrough. Combat outcomes are whatever the production owners
  produce.
- **Earned saves (prior route driver):** the R13 compatibility saves come from the lead's chain driver (legs 01/02, the
  hashes in its audit). They are loaded, not re-earned.

## Known limits

- This chain exercises the starting spells Spark and Heal. Coverage of these two is not coverage of every spell.
- Hive and the return route are not part of this ordinary-input chain (matrix case 2). The expanded
  `cave_fighting_handoff_test` separately exercises Hive → fresh Jungle, exact magic checkpoint and earned fighting
  state preservation, then a Jungle disk reload. Its health/mana/cooldown are supplied fixtures. Malformed Dawn
  state and conflicting fighting ownership are rejected without changing the receiving host in those tested cases.
  This is not proof that every malformed handoff is atomic.
- Falling below the cave floor runs the walkthrough's fall recovery (`_reset`), which also restores health to 30. That
  is existing recovery behaviour, observed when a test placement fell through; the chain asserts that it did not run.

## Versioned Cave → Museum admission (post-R14, 2026-10-12)

The live Cave completion packet now carries `cave_transfer_version: 1`. Before leaving, the Cave requires that marker plus all ten existing top-level fields: collected, equipped_item, equipped_armor, item_effects, health, player_form, curse, magic, fighting and chamber_complete. Museum also requires those fields whenever the marker is present. Existing validators still check their contents. Unknown, malformed and nonfinite versions are rejected; JSON's numeric1 remains valid. A `legacy:true` field does not bypass a version1 requirement.

Older unversioned packets retain the existing optional-field behavior, including empty, inventory-only, partial-health and complete packets. Packet age is not guessed from health/magic fields. This marker is for the live transfer, not a new disk-save format: loading an old Cave save causes the current producer to emit version1 on departure.

The controlled negative probe removed magic from a supplied packet with13 mana: the previous validator accepted it and Museum defaulted to20. This reproduces an omission risk, not an observed drop by the normal Cave producer. The stricter live sender rejects an incomplete current packet before scene change; it retains player state and allows the chamber sequence to be retried. A version marker removed from a live packet is also rejected. Directly injected invalid Museum packets keep the existing whole-rejection/fresh-initialization behavior; the live sender prevents that situation in normal travel.

`cave_museum_transfer_test` checks every missing field, invalid versions, a legacy-flag bypass attempt, JSON roundtrip, full and partial unversioned compatibility, and inherited production departure admission with each of11 marker/field omissions. Failed sends leave the Cave's saved player state unchanged and remain retryable; a corrected packet leaves normally. Receiver checks include magic13, captain gear, fighting XP, an Aloe effect and human/transformed curse states. The omission fixture overrides only packet production. Two early fixture runs passed assertions but leaked preallocated Nodes when replacing an instantiated scene's script; the final fixture constructs the subclass directly and does not suppress engine errors.

Legacy inputs still permit defaults, and nested packet semantics remain owned by the existing validators. This is not a guarantee against arbitrary packet corruption, a redesign of other area loaders, or full world-state continuity. R14 binaries and personal saves are unchanged. Evidence: `AI_COMMS/classic_review_20261007/lead/cave_transfer_version_20261012`.

Validation: focused6/6 PASS/source-stable, covering the transfer contract, Cave→Museum→Jungle/HUD continuity, new-process reload, magic, fighting/Hive return and two archived R13 saves. Four integrated code/test paths match the tested revision; the complete runtime/test snapshot differs only in the isolated project name. Full next-candidate suite/campaign/package qualification remains pending.

## Museum → Jungle departure contract

`scripts/lol2/player_handoff_contract.gd` lists the player fields a current Museum departure must carry: collected,
item_effects, equipped_item, equipped_armor, health, player_form, curse, magic, fighting.
- `enter_mirror` and `enter_dragon` check the packet `inventory_state()` just built, after `validate_inventory`.
- On a refusal the Museum stays usable, no `lol2_jungle_handoff` meta is published, and the reason ("Player state
  incomplete (…)") shows on its interaction label.
- The Jungle receiver and save loaders are unchanged. No marker is stored, so Hive packets (magic/fighting under
  `quests`) and old saves are not affected.

`player_handoff_contract_test` (rendered, `--demo-interface`; component-level):
- It builds a real Cave packet with the production `_completion_state()` (supplied XP 10, health 17, mana 13 with
  Heal).
- A test subclass of the real Museum drops one field from `inventory_state()`. The real E key at the Shining Path
  approach must refuse each of the 9 fields with the Museum unchanged.
- With nothing dropped, the departure travels and the Jungle equals the Museum except for bounded regeneration.
- On the Museum code from before this contract, the same test fails with "museum left without fighting": the Jungle
  would have started that field fresh.
- `collected` and the equipment fields were already refused by `validate_inventory`.
