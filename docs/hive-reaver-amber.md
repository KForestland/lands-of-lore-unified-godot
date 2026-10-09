# Hive Reaver alcove, ceiling collapse and Amber vein

`tools/prepare_hive_reaver_amber.py` pins the records byte for byte. It writes
`scripts/lol2/hive_reaver_amber_source.json` and stages the assembly textures and item icons in
`assets/lol2/generated/hive_reaver_amber/` (local, original media). `tools/verify_hive_reaver_amber_native.py`
checks the native code spans listed below (results in `docs/hive-reaver-amber-native-checks.json`).

## Source

**control121, the Reaver alcove** (template29; selector 0 shows the sword in the wall, selector 1 the empty slot):
- Take (kind4 mode0, state0, g6844): selector 1, state 1, one "18-Reaver of GO" (identity 0xF470CF20).
- Selector-1 callback (kind3 value1, g6874): state 2, and the timer is reset to a fresh duration.
- Timer (flag 0x10 seconds, range 5..10, running from the start) at state 2 (g6894): raises region 365's floor from −235 to −234, then stops.

**The collapse.** Moving a region surface raises region events, dispatched by F2FC0 to region-owned kind11 records (`collect_owners` does not parse these):
- Floor up/down: start events 0/1, end events 4/5.
- Ceiling up/down: start events 2/3, end events 6/7.

The 1-unit floor nudge on region 365 sets off this chain:

| Event | Group | Effect |
|---|---|---|
| 365 floor start | 262 | Alcove floor (364) rises to −185 |
| 364 floor end | 222 | Alcove ceiling drops to −185 (alcove sealed) |
| 364 ceiling end | 250 | Ceiling 365 drops to −234 |
| 365 ceiling start | 408 | Ceiling 366 drops to −235 (speed 4) |
| 366 ceiling start | 420 | Ceiling 367 drops to −235 |
| 367 ceiling end | 446 | Ceiling 368 drops to −235 |
| 368 ceiling end | 474 | Ceiling 369 drops to −200 |
| 369 ceiling end | 532 | Ceiling 370 drops to −185 |
| 370 ceiling end | 560 | op204 materials on regions 364..370, props property 2 |

The trap is a chasing ceiling collapse that permanently seals the corridor from 364 to 368; the player escapes toward region 371. It is not a pit: region 365's floor only moves +1.

**op196** (64DDC, reached from the 0xC4 branch at 649B3):
- u16 region, s16 target.
- Byte 6 bit 0 selects the ceiling (1) or the floor (0); bit 3 makes the target relative.
- Byte 7 is the speed. The per-step change is speed×10/4 × [0x22C54]/60.

**The native mover check** (B861C/B6D98) blocks a surface move that an occupant does not fit under. No damage path was found.

**control123, the Amber vein** (template27; four selector textures, material 27 needs the current exporter):
- Take at states 0, 1 and 2: one "110-Amber" each (identity 0x7F859FB9, handler 0, no use).
- States go 0 → 1 → 2 → 5; state 5 shows selector 3. The harvest at state 2 also enables and resets the timer.
- Timer (flag 0x10, range 32..144 s, running) at state 5: back to selector 2 / state 2, so one Amber regrows per period.

**Reaver handler 18:** equipping (event 10) sets player byte 0x2270E bit 3, and unequipping (event 11) clears it. No reader has been traced.

## Port

- `hive_reaver_amber_state.gd` holds the pure state, the timers and the data-driven event engine. Long steps are split, so chained movers get the remaining time.
- `hive_reaver_amber.gd` is the live Hive owner, saved as `quests.hive_reaver_amber` and validated in `act_one_quest_state.gd`.
- `hive_amber_items.gd` holds the Amber pool of 12 ids, a modern capacity adapter.
- Catalog:
  - The Reaver is a weapon, using the shared melee adapter. `tools/prepare_act_one_item_defenses.py` now also pins its
    definition17 row: signed byte41 is −50. The port adds a weapon's byte41 to the defense scalar, and a total of 0 or
    less uses the baseline damage path, so equipping the Reaver cancels armor and shield defense.
  - Amber is a plain item whose source name "110-Amber" matches Kityara's Amber offer identity.

## Adapters

- **Use:** E at an aimed control in reach. Hive pickups go straight into the inventory.
- **Timers:** the midpoint of each source range (Reaver 7.5 s, Amber 88 s).
- **Speed:** byte7 × 2.5 units/s. This assumes [0x22C54] counts 16.16 ticks at 60/s (not traced).
- **Occupants:** a ceiling stops 2 units above a player standing under it, and the chain waits. A rising floor carries a standing player.
- **Not hosted:**
  - op204 region materials, op9 prop properties, op208, op20 sounds.
  - The alternative region-365 triggers from hit props 401/426/676/725.
  - The Reaver equip flag.

Test: `tests/hive_reaver_amber_live_test.gd` (registered in `tools/run_regressions.py`).

Independent escape check starts from a supplied pickup vantage, dispatches E, then uses production grounded movement through six shared source portals with no repositioning after pickup. Engine-driven timer, pause gating, following ceiling, safe region371 and disk reload pass. Reaver equipment is tested through the inventory; its original negative50 defense is shown in the item details.
