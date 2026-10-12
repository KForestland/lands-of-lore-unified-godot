# Act One R14 verification — 2026-10-12

R14 is the current route-verified and Linux-package-verified candidate. Full content and owner acceptance remain open.

Candidate: `/home/bob/lol2_act1_candidate_20261012_r14`.
Local playtest: `/home/bob/lol2_playtests/r14/play.sh` (separate, initially empty save folder; R13 saves unchanged).
Source publication before qualification: `1fcee47`. Exact tested source is pinned by the archived reports and candidate manifest; the shared checkout's Git HEAD is not the runtime baseline.

## Changes since R13

Shared original-style HUD across Cave, Museum, Jungle and Hive; consistent Character display of skills/XP, equipment, form, health/mana and selected spell. Includes Museum jumping, location/F8 reporting, tavern departure/return behavior, the LIZ room and one-time wax pickup, and the corrected player continuity checker. See [HUD review](hud-r4-continuity-review.md) and [continuity contract](player-continuity.md).

## Verified results

- All 326 registered regressions PASS with stable source, including the HUD and corrected continuity chain/new-process reload checks. Two archived R13 saves load through the HUD. The separate Hive→Jungle return check covers magic/fighting and disk reload.
- Fresh 11-leg campaign PASS: cave → Museum → Jungle/Hive → flute → wax → runes → return → knowledge → translation → repair → darker-jungle departure. Each leg uses the preceding saved output. Final audit requires Kityara, preserves earned equipment, and checks repaired-sword acquisition and broken-sword/orb consumption.
- Sealed campaign manifest and independent archive/source linkage PASS: all 1,084 tested source entries match the candidate manifest; two additional staging/route tools (`prepare_standalone_demo.py` and `run_act1_fresh_chain.py`) are separately pinned.
- Linux and Windows exports PASS with identical PCK hash `1d554ff9e2f153278634847df6634da8e5e54f61a090cad94e0ef19d2fd551de`. All 21,333 packed assets match; all ten HUD images decode from the pack without loose asset fallback.
- Actual Linux executable: cave movement/save/load/process restart PASS; captain pickup/reload PASS using the documented legacy fixture; earned Jungle save resume/movement/F5/F9 PASS.
- Final Jungle screenshot inspected: HUD, rings, bars and coordinate overlay readable without observed overlap. SHA256 `d1bf871b30a1c9ca56eb7df46a3409aa9adbee5e2f529d76ff066b99dbfebcdc`.

## Evidence locations

- Full suite: `/home/bob/AI_COMMS/classic_review_20261007/lead/act1_r14_full326_20261012T043938Z`.
- Fresh campaign: `/home/bob/AI_COMMS/classic_review_20261007/lead/act1_r14_campaign_20261012T051500Z`.
- Packaged Jungle: `/home/bob/AI_COMMS/classic_review_20261007/lead/packaged_jungle_review_r14/20261012T051501Z`.
- Continuity receipts: `/home/bob/AI_COMMS/classic_review_20261007/lead/r14_continuity_receipts_20261012`.
- Candidate summary: `packaging_checks.json`; export hashes: `SHA256SUMS`.

## Limits and next work

The linked campaign is an automated route, not exhaustive original-game content coverage. Focused HUD/continuity tests have labelled supplied placements/items/movie gates; their selected-player-field projection does not cover every world/quest/effect field. The package tests use private Xvfb/software rendering and isolated saves. Windows export is built but has not been executed natively. Clean-machine media preparation, representative GPU/audio checks, optional content gaps and owner acceptance remain open. Combat tuning and the reported cave/inn repairs remain deferred.

R13/hotfix1 and their saves remain unchanged. The new launcher is opt-in and starts with a separate save folder. Next: owner playtest of R14, reconcile the remaining required-content gaps, then continue the connected campaign into later areas using the established state owners.
