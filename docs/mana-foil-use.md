# Mana Foil use — private work in progress

Both `cave:control75:Mana_foil` and `jungle:magic_shop:Mana_foil` bind definition133/handler43. The shared human inventory adapter consumes one carried foil and applies the original D6A88 +50 adjustment to the shared mana owner. Consumption happens even at the cap. The arithmetic preserves signed32 wrap and the native upper-cap-before-zero-clamp ordering; stored values use the existing unsigned32 magic packet representation.

Sources: `AI_COMMS/grok_backlog_20261028/G07_mana_foil/` pins original handler983B8, definition identityC221EB6B and consumption order. Independent `AI_COMMS/codex_act1_review_20261028/mana_foil_adjustment_review.json` executes complete D6A88 and the original UI-suppressed7CE80 path for50 boundary cases without helper stubs. The checked cases are copied into `tests/fixtures/mana_foil_native_adjustment.json`. Player fields141/145 correspond to maximum/current in the existing magic progression owner; this effect does not award experience or alter the regeneration timer.

No new effect packet is needed: the shared spent list and magic packet retain consumption and mana. Cave source pickup receipts must remain in place; Cave carried-items filtering removes spent items without erasing those receipts. The UI names the action and explains consumption at full mana.

Verified privately: all50 arithmetic fixtures; both IDs through the actual Museum inventory button with supplied carried items; transformed-form refusal; repeat-use refusal; +50 and full-cap behavior; host save/load; a fresh-process restore; existing catalog checks. These do not prove earned Cave pickup, a shop purchase, Cave conservation, cross-host travel, or rendered use. Original sound request binding remains unresolved and no guessed sound is played. Not ready for release integration.

Cave persistence follow-up: `mana_foil_cave_test` supplies the control75 pickup receipt,
uses the actual Cave item controller, and checks receipt retention, consumed inventory,
60 mana, disk save/load, rejection of spent foil without a pickup receipt, and the actual
Cave completion packet imported into Museum. It reproduced a save rejection before
fixing Cave validation to include both stone/foil pickup receipts. The corrected test
passes headless. This does not qualify earned pickup, fresh-process Cave restart, or rendering.

`mana_foil_cave_restart_test` also passes in a fresh process against the Cave producer save: pickup receipt, spent state, 60 mana, and duplicate-use refusal. Earned pickup and rendering remain unqualified.

`mana_foil_shop_test` passes headless through actual shop introduction/return/offer, visible sprite1 click and one-shot flag50, item use, Jungle disk save/load, room re-entry without respawn, and actual Hive handoff. Room entry and starting mana are supplied; this is not a walked shop approach or rendered qualification. The first added Hive assertion ran before deferred controller setup and was corrected to wait one frame.
