# Village gate leaves 78/79 (betrayal escape)

Source consumer `scripts/lol2/jungle_gate_leaves_state.gd` from `tools/prepare_jungle_gate_leaves.py` (L4_HJ archive 517afe6d…, geometry 445d9b27…, texture 98c97fab…; VILLAGE_ESCAPE_CONTRACT.md; Codex gate_movable_binding.json, gate_level_binding.json).

- **Records**: leaf78 group 28068 and leaf79 group 28140, kind9 value2048, predicate196 = local39 Killed_Confidante==1 AND shared29 GV_HULINE_ALERT==1; mask0 0x0800 (mask1 0), threshold1, mode4 (after-durability <= 1); placement durability 5; Jungle level index 4 (no level-5 special).
- **Accepted context**: sound452 (jugcrash) at control81; link control81 (leaf78) or control80 (leaf79); unlink the leaf. Controls 80/81 are template74, one flat 80×167×2 box with gate materials 514/742: the fallen leaf. An unlinked leaf has no mesh and no collision; alarm closures (movable targets) never relink it.
- **Rejected context** (mask, durability, predicate, unlinked leaf, malformed): no change.
- **Source relink (reset on entry only)**: regions 588/3895/3896/3897 (east of the village, no predicate) relink both leaves and unlink both fallen leaves when Luther ENTERS one of them (an entry edge of the grounded region history). Standing inside, the alarm, loading a save or restarting the game never relink: the region history (`inside`) is saved with the packet and restored before entry detection, so a save made inside region588 loads without a reset (Codex decision on 66b274e, 2026-10-25).
- **Saved** as `quest_state.jungle_gate_leaves` (leaf/fallen-leaf pairing validated with the whole save).

## Owner-approved modern binding (the owner, 2026-10-25)
The native producer of the 0x0800 hit context is not traced. The port supplies it only through **Force gate**: press E while aiming at a closed, reachable, unoccluded leaf. It supplies mask0 0x0800 with before-durability 5 and after-durability 0 to the source consumer. It is not the original sword or Spark behaviour and computes no damage. Without the alert the hint reads "The village gate is closed."; with the alert but the Confidante alive it reads "The gate is barred and watched. You cannot force it now." A carried held item is put away first and never consumed.
