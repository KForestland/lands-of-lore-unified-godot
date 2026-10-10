# Fire crystals and the Museum sconce recharge

`tools/verify_fire_crystal_sources.py` pins the source facts; results are in `docs/fire-crystal-checks.json`.

## Source

- **The two items:**
  - "57a-Fire crstl": GLOBAL definition57, identity 0xE7B89177, handler2.
  - "57b-Fire brnt" (burnt): definition58, identity 0xDDC02377, handler0.
- **Handler2** (0x96080) runs on event1:
  1. It spends one charge (item byte +4, which is the op3/give_item property).
  2. It searches for a target (E11C8) and spawns fire effect pool object 0x6E from the player.
  3. When the charges reach 0, it replaces the held crystal with the item built from a runtime definition entry, which by the 57a/57b pairing is the burnt crystal (an inference).
- **The MAGIC room** sells three crystals with property4, which means 4 charges.
- **All 23 Museum sconces** (controls 117..139) carry one kind4 mode3 record at owner state1 (lit), holding "57b-Fire brnt":
  - op2 player 0x18 takes the held crystal;
  - op3 "57a-Fire crstl" with property1 gives back a crystal with 1 charge.

## Reachability in Act 1

The scope checked is the grants in L1_DC/L3_DH/L4_HJ/L5_HC and the arrival and transition tables.
- No grant gives "57b-Fire brnt"; a crystal is burnt only by using up its charges.
- "57a-Fire crstl" comes only from the sconce record and from the Jungle magic shop.
- L3_DH (the Museum) is entered only from L1_DC.
- So a burnt crystal cannot be held in the Museum in normal Act 1 play, and the recharge is implemented and tested with a supplied crystal.
- Uncertainty: Museum arrival entries 0/2/3 have no listed source.

## Port

- **Catalog:** the shop crystals have use `fire_crystal`. Charges live in item effects as `fire_crystals` (id → 0..4) and are validated, saved and carried across areas.
  - A missing entry means a shop crystal with 4 charges.
  - 0 is burnt: the same carried id stands in for 57b, as an adapter.
- **Use:** the inventory's "Use crystal" spends one charge, then fires `player_starting_magic.crystal_fire()`.
  - This is the shared Spark ray and creature-damage path: 8 damage on the non-melee reward path. It has no Spark-only receivers and draws an orange beam.
  - A miss still spends the charge, as in the source.
  - A burnt crystal refuses use. The status line shows its charges or "burnt out".
- **Recharge:** with the sconces lit and a burnt crystal in hand, E at a lit sconce (`museum_key_locks.gd`) rekindles the crystal to 1 charge and clears the hand.

## Adapters

- **Damage:** fire damage 8 through the Spark path.
- **Same carried id:** the source replaces the item instead.
- **Burn-out:** happens at 0 charges even when the last use found no target. The source replaces the item only on its target path.
- **Saves:** a Fire crystal is a Jungle-scope item, so a Museum save carrying one is outside the Act 1 catalog scope. The supplied recharge test does not save in the Museum.

## Tests

**`tests/fire_crystal_live_test.gd`** (actual Jungle host):
- A crystal earned by the real shop sprite click.
- Four "Use crystal" presses, the first striking a source dino for 8, then burnt and refused.
- The status line, a disk save and load, validation negatives, and the Jungle → Hive handoff.

**`tests/museum_sconce_recharge_test.gd`** (actual Museum host, supplied crystal):
- An unlit sconce is refused.
- After the real Sk-key locks light the sconces, a lit sconce rekindles the crystal, and a charged crystal is ignored.
- The rekindled crystal fires once and burns out again.
- control134 also rekindles.
