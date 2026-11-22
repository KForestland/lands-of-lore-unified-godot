# F-08 pre-migration save baselines

These are component fixtures, not earned campaign saves. The tests supply explicit prerequisites and call the original production grant, save and load methods. No production owner uses `item_grants.gd` yet.

`*_after_grants.json` are actual files written by the original host save methods after the named grant sites. Their byte hashes are pinned in `manifest.json`. The twelve host/area files cover all thirteen named section-4 sites; L14 includes both shard and trial idol, and L16 preserves the ball fountain grant before the dry fountain grant.

`*_loaded.json` record observations after a fresh scene loads the corresponding file through its real legacy reader. `legacy_loaded.json` records the fifteen original area goldens. `legacy_variants.json` records the fifteen existing round-trips, Cave v1 and five Plan 1 witnesses. All thirty-six pre-existing golden packets retain their original bytes. Loaded records compare inventory order, history and relevant owner queries; their canonical quest-state view excludes native-script and actor-population bookkeeping. The raw post-grant save files remain independently byte-pinned.

Run `item_grant_host_save_test` with the normal regression runner and staged assets. Default mode writes temporary saves under `user://tests`, compares the pinned repository files and never rewrites them. The separate site and history tests pin normal/full-pack outcomes, text, Journal, HUD and history spelling.

The explicit `LOL2_WRITE_ITEM_BASELINES=1` mode created these pre-migration records from base `20c7797`. Do not regenerate them to accept a migration difference. Review and explain any changed baseline independently. The fast census also pins this corpus, the site/history baselines and the original golden files.
