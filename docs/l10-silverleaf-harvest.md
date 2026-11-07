# Nine Silverleaves to the Wild Village

STORY-031 uses the actual STORY030 growth save. The harvest owner wraps the
original tree grants159..170 with unique persistent identities, so a tree cannot
produce duplicate leaves after save/reload. Definition117 retains its existing
original-item handler (+5 mana if consumed); this route keeps all nine leaves.
See `l10-silverleaf-source.json` and `verify_l10_silverleaf_source.py` for the
byte-pinned source grants. This is a world pickup, not a receptacle or charger.

The route harvests159,170,164,167,169,166,163,160,162 in that order, then takes
the native cemetery exit to Savage Jungle selector2 and walks to the Wild
Village. Twelve original tree grant props exist; the route does not invent nine
item placements or imply only nine trees exist. The three unvisited trees are
still available. DEVIATIONS0251 records the saved one-pick-per-tree adapter.

The first attempted path to tree161 crossed an unsafe edge beside the Emperor
stairwell and caused fall recovery. That run failed; no output from it qualifies.
The revised route follows the surface paths and retains strict no-reset checks.
Each pick tests capacity refusal without loss, duplicate refusal, and actual
save/reload before the next tree. No items are seeded or inventories merged.

The first surface-route run completed but its generic combat helper attacked
the admitted village guard113. That ending was rejected. The revised route
stops at conversation range, the helper respects peaceful interaction actors,
and the Act2 owner keeps guard113 peaceful after earned village admission.
No guard health or position is reset; the test requires his original500 health.
This allegiance rule is a modern adapter recorded in DEVIATIONS0251.

READY qualification:4/4 PASS, source stable,
`tmp/regressions/l10_silverleaf_harvest_ready/report.json`
SHA256`cf3aa9bf1afc2a10281f87040172b53b892b0ffc6d53e80fab9839edfb20b82e`.
L8 creatures5.55s, L10 creatures6.84s, fresh growth63.84s, full harvest/return326.13s.
Final earned save `tmp/l8_nine_silverleaf_earned_save.json`
SHA256`6c558bf3bdd673a65518da3ee2f8a3195f00d6978c04f57390555e3c791826d9`; nine leaves, guard113 health500.
