# Hive Net of Exile (prop214)

`tools/prepare_hive_net_exile.py` pins the record. It writes `scripts/lol2/hive_net_exile_source.json` and stages the original pile sprite and the item icon in `assets/lol2/generated/hive_net_exile/` (local, original media).

## Source

- **Prop214** is a bone-and-branch pile (template42, selector2) at (−2689, −539, −9055), region350.
- **Its only record** is kind4 mode0 (empty hand) at owner state0, group1632:
  - op3 player "26-Net of Exile" (identity 0x1EDB305A, property4: one item);
  - op16 state1.
- **The pile stays:** the selector never changes; state1 only stops a second take.
- **The item** is GLOBAL definition25, handler104 (0x9B718).
  - It handles only event17, a hit.
  - When the target's class is 2, it allocates pool object 0x7A and calls the family-4 effect constructor 10E2F8 with the attacker and the target.
- **Defense:** byte41 is 0, now pinned in `prepare_act_one_item_defenses.py`.

## Port

- **Owner:** `hive_net_exile.gd`, saved as `quests.hive_net_exile` `{version, state}` and validated in `act_one_quest_state.gd`.
- **Transport:** a carried Net needs pickup history (state1). `hive_review.apply_area_handoff` enforces this.
- **Catalog:** the Net is a weapon that uses the shared melee adapter. Names and shop presentation are added.
- **Route tests:** the exact quest-packet expectations in `hive_route_test` and `hive_small_route_test` include its initial packet.

## Adapters and limits

- **Pickup:** E with the pile aimed and in reach. The Net goes straight into the Hive inventory.
- **Pile sprite:** the pile isn't among the staged single-state Hive props, so the owner draws it as a fixed-Y billboard.
- **On-hit:** the handler104 effect is now hosted as a modern 10 s hold; see `docs/net-exile-onhit.md`.

Test: `tests/hive_net_exile_live_test.gd` (registered in `tools/run_regressions.py`).
