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
| Hive | `area_handoff()` (`inventory` + `quests`) |
| Saves/handoffs | `from_save()`: Museum `checkpoint` saves, `{inventory, quests}` saves, bare packets |

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
