# Act 1 R9 verification

R9 adds one-time guard and Kelsrick weapon drops, usable Guard Shields, the Museum Long arm reward/trap, and lit-sconce damage. The guard54 retirement clock now runs automatically in the live engine; a regression first reproduced the missing scheduler, then passed after the fix.

All 292 regressions passed with unchanged source. A fresh 11-leg campaign passed with linked saves and the required Kityara encounter. Both platform exports completed and share pack SHA256 `02e2b2cd1f1f612d6ccec225d618742cf73d1dc3c858bf57934ed050a31a3e3a`. All 21,127 packed assets matched. Actual Linux executable checks passed for movement, save/load/restart, captain loot, automatic guard54 retirement/pickup, and Jungle resume from the earned campaign save. The final Jungle screenshot was inspected.

This verifies the implemented route and prepared Linux package. Remaining original content, clean-machine media preparation, native Windows execution, representative GPU/audio checks and owner acceptance are still open. R8 was rejected for the guard54 scheduler defect; its partial evidence was preserved. Original game assets and personal saves are not included in this source publication.
