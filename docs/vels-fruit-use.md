# Vels fruit inventory use

Jungle world rows 54–57 ("82-Vels fruit") now show **Eat fruit** in the existing inventory. Eating consumes that
carried fruit into the saved spent history, which survives save/load and area travel. It adds no heal, mana or
other stat effect.

## Source

`tools/verify_vels_fruit_use.py` pins definition 84, identity 102901910 and handler 20, whose original relocation is
0x9732C. All 87 original handler cases pass (72 use cases, 15 other events). Results: `vels-fruit-use-source.json`.

- **Executed in replay:** the handler itself, the shared held-item removal routine 77ACC (admission gate 0x223D4,
  held slot +0x90F, held count +0x913), the unlink routine 9B8F0 (it returns its argument) and the in-handler choice
  between the primary pool [0x96918] and the fallback pool [0x9691C].
- **Call boundaries, checked by their arguments:** message E3924, cursor refresh ACA44 (held count 0), pool release
  5F830, status indicator 7C7DC and gesture 7C528.
- **Event 1** always returns 1, clears player status byte +1B5 (0x22729), calls `7C7DC(23819,0)` to turn the status
  indicator off and plays gesture `7C528(23819,4,30)`. This happens with no status present, and also when 77ACC
  refuses removal; in that refused case the fruit stays held. When removal is admitted the fruit is removed.
- **Other events** return 0 and change nothing.
- No other player global changes (sentinels checked).

## Port behaviour and differences

- Use admission reuses the existing item owners' living-human rule: a transformed or dead Luther cannot eat. In the
  port, removal is always admitted for a carried fruit, as for sap.
- **The status cure is not modelled.** The port has no player status (+1B5) model, so the cure has nothing to clear.
  No status was added to enemies. Earlier status inferences stay withdrawn (correction C1 in
  `opus/jungle_item_uses.md`).
- The indicator and gesture presentation are not reproduced.
- The consumed-item cap already derives from `ItemCatalog.consumables()`, which now counts 23 ids: 14 Aloe, 2 sap,
  4 fruit and 3 stones.

## Checks

- `jungle_fruit_use_test`. Starting state is supplied (local pickup approaches); this is not an earned route.
  - Source identity of all four rows.
  - Real E pickups and the Eat fruit button.
  - Form and death rejection.
  - Consumption with every other item and magic field unchanged; repeated use refused.
  - Disk rollback; no respawn.
  - Invalid, duplicate and carried-and-eaten histories are rejected.
  - Jungle→Hive (eaten there)→darker-jungle transport.
- `jungle_aloe_use_test` now derives the per-kind consumable counts from the source rows instead of a fixed 19.
- Focused runs: fruit, sap, both Aloe tests and the item catalog 5/5; world items, item effects, item live and
  magic-shop inventory 4/4. Both runs were source-stable.
