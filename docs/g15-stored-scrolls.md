# Stored spell scrolls

The owner's Spark, Prism and Mists “orbs” are the decoded scroll definitions, not the glass-globe/charger system. G15 also includes the named Summon scroll. Use a scroll by right-clicking its inventory cell (the existing Use button uses the same action).

| Definition | Handler | First use if unlearned | Later use |
| --- | --- | --- | --- |
| 75 Spark | 32 | Spark is already learned | Shared Spark3, cost3 |
| 149 Summon | 12 | Learn Summon3, no cast or mana | Shared Summon3, cost3 |
| 150 Mists | 34 | Learn Mists1/3, no cast or mana | Shared Mists1, cost1 |
| 151 Prism | 33 | Learn Prism5, no cast or mana | Shared Prism5, cost5 |

These are explicitly modern mode1 bindings. Native shared-callee grades remain UNKNOWN. Healing scroll148 and other levels remain unhosted. Existing Ancient highest-charge admission is unchanged. Selection stays on the player's current school.

The inventory pauses the tree. Its Use action queues one request, closes that inventory, then dispatches after its normal exit restores pause/cursor state. The shared HUD interface request handles cursor mode; no inventory/pause/death/story/cooldown/target guard is disabled. Refusal closes the inventory and gives the shared plain HUD line while preserving item and mana. No clocks advance while browsing. A map change/closed host cancels the queued request; one pending request prevents double consumption.

A final preflight checks the carried identity, spent history and any live Museum placement receipt. The effect and consumption have no await between them. A successful learning/cast removes one source identity, records spent, updates Museum consumed receipts where applicable, and synchronizes Act2 carried state while retaining collected history. Missing Museum placement packets can be reconstructed from already-carried/spent Museum identities; present packets remain strictly validated. Original pickups remain unique and do not respawn.

Rendered tests use actual I and inventory-grid right clicks, actual E for the Museum Summon pickup, and actual F5/F9. Local stand/grant/clock and intro fixtures are declared as audited source sites; these are component proofs, not newly earned campaign walks. They cover first learning, same target receivers, fixed costs, selection preservation, no-target/cooldown refusal, HUD-cursor use, inventory world-key blocking, source receipts and reload.
