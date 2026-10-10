# Jungle Kelsrick64 (L4_HJ actor64, definition7)

Status: **integrated slice, fixture-tested; not an earned route and not owner-accepted.**

## Source chain (pinned `scripts/lol2/jungle_kelsrick_source.json`)
- Regions 2750/3567/3791 (grounded entry edges, saved as `inside`) → event20 chains. Talk1 needs control99 village
  speech completion (local15=1, pred176): 7146→30632 E079E seg1 (hold 0x26 + reposition) → seg end event0 → 30684
  (release 0x27, control98 request). Region2750 → owner1/local8=3; talk2 E081E; region3791 → owner2; talk3 E080E;
  talk4 E082E. No repeats.
- Kind4 has one record (30710, mode1): a **held** item plays the refusal (E079E seg2) at owner state0 only.
  Empty-hand E does nothing (no invented talk).
- Kind9 hits: melee context 2/4 and Spark 1/1 → 30456 (one-shot): owner40, local52, shared29 (Huline alert),
  seg3 → 30756 wake → hostile. Type 0x60 → 30402 + A7544 death → event11 31122: GV_KELSRICK_DEAD, soul −1.
- Actor op3 only gives Kelsrick his own sword (event9 31170). The scripted grant remains actor-owned; the modern corpse pickup is documented in `kelsrick-loot.md`.
- Reachable values are derived from the source: owner {0,1,2,3,5,40}, poses {9,10,11,12,15,16}, B5 bits 0x0D.

## Runtime
- `scripts/lol2/jungle_kelsrick_state.gd`: source state; `jungle_kelsrick_packet.gd`: portable validator
  (registered in `act_one_quest_state.gd` as `jungle_kelsrick`); `jungle_kelsrick.gd`: live controller.
- Body/fight: unchanged generic `scripted_creature_population.gd` (subclassed only to record melee vs Spark),
  `jungle_kelsrick_population_source.json` from `tools/prepare_jungle_kelsrick_population.py` (attack30/def0,
  A1F57 corrected replay; attacks sel4/sel5).
- Host (`jungle_walkthrough.gd`): `kelsrick`, `hand_item`, `actor_input_locked()` (Bacatta escort or Kelsrick hold),
  `_kelsrick_context()`/`_kelsrick_shared()`. **Shared29 is the village gate's existing `shared29`** (its admission
  requires 0), not a parallel global; shared0/11 are monastery `GV_LUTHERS_SOUL` (cap10) / `GV_KELSRICK_DEAD`.
  Spark aura merges Kelsrick targets. Strikes are live whenever he is alive outside a clip/hold.
- External control/prop/movable rows are kept as saved `receipts` (raw hex), not executed and not dropped.

## Open / adapter
- Grok live_profiles.json: after 30756 (B5 0x0C) Kelsrick gets behavior **5 Get player**, action 1, no spells. This
  confirms that the hostile branch pursues and melees (as the generic population does).
- Jungle inventory exposes "Hold in hand" through `hold_in_hand`; the live Kelsrick test uses this production
  action before the aimed offer. Fresh rendered recheck passed 2026-10-07 in
  `tmp/regressions/act1_story_resume_20261007`. This remains fixture coverage, not an earned approach.
- Receipts (control98 etc.) are not bound to consumers.
- Death presentation uses the generic def7 death/corpse clips.
- Bob still has to review the clip scale and framing (the reposition puts the camera low and close).

## Tests
`tests/jungle_kelsrick_state_test.gd` (portable) and `tests/jungle_kelsrick_live_test.gd` (rendered, production host).
