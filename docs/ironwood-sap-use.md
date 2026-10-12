# Ironwood sap inventory use

Jungle world rows52/53 now expose **Use sap** through the existing inventory.
The action consumes that specific carried item and retains its pickup and spent
history through save/load and area travel. It adds no player stat effect.

`tools/verify_ironwood_sap_use.py` pins definition111, identity1690340112,
handler98 and its original relocation to0x9B2A0. All24 original handler cases
pass: event1 consumes when held-item removal is admitted; other tested events
return0. The complete handler contains no additional stat-effect call.
UI presentation, unlink and pool release are explicit replay boundaries;
the shared held-item removal routine is executed. This does not classify
crafting or world-target interactions with sap. Human-only and living-player
inventory admission reuse the current modern adapter.

`jungle_sap_use_test` passes with real E pickups from supplied local approaches,
the inventory button, form rejection, unchanged health/effects, repeat rejection,
disk rollback, no respawn, invalid-history rejection and Jungle→Hive→darker-jungle
transport. This is not an earned walking route. Catalog and Aloe checks also
pass in `tmp/regressions/sap_use_20261009`.

That run exposed a real pre-existing startup race: the drunk-villager physics
callback could run before the deferred StartingMagic node existed. Its live
gate now waits for a valid node. Both the original failing item-travel test and
the drunk encounter test pass in `tmp/regressions/sap_startup_followup_20261009`.
Both runs retain source-stability receipts and the original failure log.
The current full suite and campaign have not yet run.
