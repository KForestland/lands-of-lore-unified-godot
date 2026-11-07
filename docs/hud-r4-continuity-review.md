# HUD r4 and player continuity review — 2026-10-12

Integrated 15 source/document/test/tool paths into development main after checking every captured main source hash remained unchanged. local `AI_COMMS/classic_review_20261007/lead/hud_r4_review_20261012/integration_receipt.json` records backups, before/after hashes and PASS linkage to the independently tested source. Project name and private display wrapper are intentionally excluded from linkage. One trailing blank line was removed from the chain test after validation; the receipt records both hashes and the byte-identical substantive content.

The shared Character page now exposes fighting/magic level and XP, selected spell, form, health/mana and equipment in Cave, Museum, Jungle and Hive. R4 also fixes stale cave equipment display, inventory/load return controls and compact HUD layout.

Validation:
- Frozen r4: six focused tests PASS/source-stable (`r4_frozen/report.json`).
- Corrected comparator contract, rendered HUD acceptance and extended fighting/Hive return: PASS/source-stable (`corrected/report.json`, those three tests only).
- Corrected travel plus new-process restart: 2/2 PASS/source-stable (`corrected_chain/report.json`). Two older R13 route saves also load through the HUD.
- The first corrected travel run failed because its aggregate check still used an obsolete unbounded mana rule; dependent restart rejected mismatched stale receipts. Both failed logs retained. The test was corrected; no game state-loss fix was required.
- Before/after negative probe proves detection of an expected field absent from both snapshots, nonfinite mana and duplicated carried identity. Contract tests add spent-item counts, malformed ranges and time-bounded refill rejection.
- Return test checks Hive → fresh Jungle and disk reload, exact magic checkpoint including cooldown and fighting progression. Malformed Dawn and conflicting fighting-owner packets are rejected without changing the tested receiving state. Grok's malformed-Dawn mutation hypothesis was not reproduced.
- Representative Character screenshots inspected for all four hosts. Accepted save receipts/screenshots copied to `accepted_receipts`; original frozen receipts preserved separately.

Limits: travel uses real attack/cast/item/equip/input paths but supplied items, positions and movie gates; it is not an unassisted full campaign. Comparator projects selected player fields, not all world/quest/effect state. New full candidate/campaign/package qualification remains next. R13 and hotfix1 binaries/user saves unchanged.
