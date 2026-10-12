# Act One R16 verification — 2026-10-12

R16 is route-verified and Linux-package-verified. Full content and owner acceptance remain open.

Candidate: `/home/bob/lol2_act1_candidate_20261012_r16`. Opt-in launcher: `/home/bob/lol2_playtests/r16/play.sh`, with a separate initially empty save folder. R14 and existing saves are preserved. Source publication before qualification: `223804e`; exact tested source is pinned by archive and candidate manifests, not the main checkout Git HEAD.

## Changes and results

Museum urn pickups yield two independently identified ivory chips with saved world receipts; Cave departure requires a complete versioned player transfer. The catalog test fixture now supplies matching chip receipts and pins45 Museum items. No lift timing tolerance or production audio change.

- All330 registered tests PASS/source-stable, including unchanged lift audio/walk check, HUD, player continuity and process restart.
- Fresh11 linked campaign PASS including Kityara and final darker-jungle departure. Campaign is automated route coverage, not exhaustive content acceptance.
- Archive/source linkage PASS; all1093 tested entries match stage, with2 separately pinned staging/route tools.
- Linux and Windows exports PASS; shared PCK SHA256 `8e50cf1864304d52ca970bdb51d325f9eb9b3677dfa5eab79e4d64789677de23`.
- All21336 packed assets match, including successful decoding of all3 ivory images.
- Actual Linux executable save/restart, captain pickup/reload fixture, earned Jungle resume/movement/F5/F9 PASS.
- Final Jungle screenshot inspected: HUD/coordinate/save text readable without observed overlap. SHA256 `d1bf871b30a1c9ca56eb7df46a3409aa9adbee5e2f529d76ff066b99dbfebcdc`.

## Evidence and limits

Full suite: `/home/bob/AI_COMMS/classic_review_20261007/lead/act1_r16_full330_20261012T135214Z`.
Campaign: `/home/bob/AI_COMMS/classic_review_20261007/lead/act1_r16_campaign_20261012T142646Z`.
Packaged Jungle: `/home/bob/AI_COMMS/classic_review_20261007/lead/packaged_jungle_review_r16/20261012T142647Z`.
Candidate summary: `packaging_checks.json`; hashes: `SHA256SUMS`.

R15's328/330 failed run remains preserved in `lead/act1_r15_failed330_20261012T130333Z`. The catalog fixture correction passed independently; unchanged lift check passed privately and in R16. Root cause of R15's audio sample remains under investigation; no failed run relabelled.

Checks use isolated userdata and software rendering. Native Windows execution, clean-machine preparation, representative GPU/audio and owner acceptance remain open. Full earned ivory detour chaining and optional effects remain outside the feature slice. Combat/cave-inn changes stay deferred.

Next iteration: approved Godot diagnostics and test reliability work. Private diagnostics patches and other unreviewed collaborator changes are not included in R16.
