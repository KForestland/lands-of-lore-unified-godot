# Act 1 candidate R3 — 2026-10-07

Technical QA candidate: `/home/bob/lol2_act1_candidate_20261007_r3`. Bob has not accepted the demo. The goal remains the complete cave → Museum → Jungle/Hive and connected quests → darker-jungle departure, with a retained continuation save. Bob permits modern mechanics where better or faster; missing story/content remains tracked.

## Included changes

- Cave captain introduction, surrender/rewards, Museum sword skeleton/control96, shared item/equipment validation, Hive weapon handling and Jungle Aloe use.
- Production demo controls, validated cave-to-Museum transfer and stable eye-animation reloads.
- Pre-exit woman conversations and Hive Dawn appearance/translation/attack story branches.
- Automatic modern combat in both Dawn encounters: visible charge and bolts, wall blocking, equipment/protection-aware damage, pause and saved in-flight projectiles. Baseline damage is6 on the30-health player; charge0.65s and interval2.2s are deliberate tuning.
- Corrected partial-codebook movie decoding; malformed-input handling and original local media checks.

Chainbolt/Plasma variants are not in R3. Opus owns their isolated integration; independent review identified repeat damage from callback checkpoints and near-target wall bypass in the standalone J release. Those defects must be fixed before integration.

## Verified and pending

The Linux export completed and passed actual ordinary-key movement, F5/F9 reload and process-restart loading in isolated user data. Both reload position deltas were0. Packaged Jungle UI resume from a fresh earned save, ordinary movement and F5/F9 reload also pass. Reload increments the exit-woman callback generation3→4 as required; every other saved field matches. The initial overly strict harness failure is preserved. All16853 packed assets match their source hashes in an empty audit project. A cave screenshot was inspected; this is private-Xvfb evidence, not representative GPU or audible playback acceptance.

Evidence is in the candidate's `packaging_checks.json` and `source_asset_manifest.json`. The current eleven-leg demo-controls campaign is running at `tmp/act1_modern_combat_chain_20261007`. Four focused Dawn checks passed on stable source; a full suite has not been rerun on R3. Older R2 and post-E3 campaign results certify their own snapshots only. Windows export completed successfully and its PCK is byte-identical to Linux. Native Windows execution is untested. Earlier Wine9 failed before engine startup even for a version-only probe.

## Content still requiring closure

- Bacatta65/prop553: missing alert-before-first-meeting branch; classified as optional original content in the actor reconciliation. Bacatta57's village-entry world role remains unresolved. Neither is silently counted as implemented.
- General creature loot and Museum prop93 treasure production remain incomplete or unverified. Ten skeleton deaths alone do not prove a treasure grant.
- Remaining hostile/optional story outcomes need their inventory reconciled against the implemented route. A successful main route does not certify these branches.
- Original HUD reconstruction, representative rendering/audio review, clean-machine asset preparation and remaining tool portability remain open. The GitHub review now includes the complete R3 runtime, scenes, Godot tests and numeric fixtures; see [source instructions](act1-source-reproduction.md).

## Bob's playtest

Technical QA and exact artifact checksums come first. Then test the identified candidate using ordinary controls and report area, action, expected/actual result and save used. The lead owns reproduction, fixes and verification. Bob's acceptance has not been recorded.
