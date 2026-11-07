# Act2 earned loop, milestone1

`tools/run_act2_silverleaf_earned_loop.py` runs29 separate headless processes continuously from the previously earned Dawn-route L8 departure through STORY027. It reuses the27 pinned campaign drivers, then physically escapes the flood and follows the original exit timers to Dawn on the Savage Jungle shore. The final `act2_silverleaf_earned_loop_test.gd` verifies the complete receipt, save hashes and surviving story state. This milestone ends at shore return; collecting nine silverleaves is later STORY030/031 work.

```
LANE_NICE=19 tools/run_lane.sh 24-31 -- python3 tools/run_act2_silverleaf_earned_loop.py
```

The input `tmp/dampen_darker_arrival_earned_save.json` is checked against SHA256 `3f41667fc5ea5e39e92fd964083d4ec1247dd5269a13afba73f49c2e3475c53d`. Its earlier earned runes/Dawn/library/departure lineage is documented in `dampen-earned-campaign.md`. The runner never edits a save or merges inventories. Generated drivers and output saves live under `tmp/act2_silverleaf_qualified/`; the earlier qualified branch is preserved separately. Source snapshots before/after every stage reject production/test drift. A resumed prefix also verifies completed drivers and saved outputs before continuing.

The source adapters are explicit: DEVIATIONS0246 covers the physical table docking/rise, water timing and raft float;0247 covers shore presentation and permanent Ruins travel refusal. Table122 uses its original collision footprint. Its modern docking drift moves below the higher source ceiling before lifting to tunnel6304 floor420, preserving ordinary jumps and avoiding ceiling removal. Raft completion earns the original control82 selector and fires the original prop104 exit timers. Dawn20 uses the existing creature owner and original source placement. No duplicate bracers are granted.

STORY004's B1 double-view note was audited separately. The current menu/audio presentation lacks repeated approach/back views; original village actions remain qualified, but that navigation is not claimed. See `l8-village-double-view-audit.md` and the backlog note.

Qualification PASS: all29 stages plus final receipt assertions, 2440.23 seconds, source stable at49ed928. Report `tmp/act2_silverleaf_qualified/route_report.json` SHA256 `5b66c5d1e139dc86eaefc499272133999c28af60a0d7ecbfd1eb1b49e308386e`. Final earned shore save `tmp/act2_silverleaf_qualified/l8_shore_earned_save.json` SHA256 `389142125824f46570ef4cdc423ad8457ce9b401c9ebdc3b83a7a31df3518c7c`. Compact receipt: `tmp/act2_silverleaf_ready_receipt.json`.
