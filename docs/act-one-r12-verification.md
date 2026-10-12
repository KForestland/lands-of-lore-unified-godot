# Act 1 R12 verification

R12 adds Museum Prism pickup, Hive Reaver/Amber and Net pickup, Cave Ancient Stone/Manafoil, and the restored shaft floor lift. The lift carries the player and pickups, respects pauses and save restoration, renders through the indexed cave compositor, and removes the vanished trigger’s collider.

All304 regressions passed with unchanged source. A fresh11-leg campaign passed on 2026-10-10 through darker-jungle arrival, including Kityara and the actual linked saves. The sealed archive matches all1049 tested source paths in the candidate; two additional candidate-only paths are staging inputs. The earlier shutdown-interrupted campaign and an interrupted retry are retained separately.

Linux and Windows exports share pack SHA256 `23e586f84d7e02a8c498d1b3f94354c38f8fcb571b0b20edcc979a33d9787b7d`; all21,205 packed assets matched. Actual Linux save/load/restart and captain pickup passed. Jungle resume through the launcher, movement and F5/F9 passed using an unchanged earned campaign save in isolated user data. The final after-reload screenshot was inspected (SHA256 `ea535d0ba4b5a7358a51250ca492e3bb2613d9909688af2418665ab8bdcd542c`). The captain check uses a documented legacy R7 checkpoint and supplied vantage; it is separate from the fresh earned route.

Local candidate: `/home/bob/lol2_act1_candidate_20261009_r12`. The full archive is `AI_COMMS/classic_review_20261007/lead/act1_r12_full304_20261009T144740Z`; the campaign archive is `lead/act1_r12_campaign_20261010T050946Z` under the same review root. Exact reports are in the candidate’s `packaging_checks.json` and `evidence/`.

R12 is the verified route/package baseline. Later cave ambience/passage fixes, Fire crystal use/recharge, Net entanglement and Prism blindness/panorama source changes are outside these binaries. Listed optional effects/content, clean-machine media preparation, native Windows execution, representative GPU/audio and owner acceptance remain open. Modern mechanics are documented adapters; this is not a complete-content or full-game acceptance claim. Original media and personal saves are not published.
