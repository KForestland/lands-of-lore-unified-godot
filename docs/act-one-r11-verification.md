# Act 1 R11 verification

R11 adds Museum Dragon Blood explosives, renewable beehive wax, Dawn library translation/Dampen, renewable Aloe and sap, and the breakable Aloe barrel. Inventory-capacity refusal and exact regrowth boundaries are checked.

All 296 regressions passed with unchanged source. All 11 fresh campaign legs passed with linked saves and the required Kityara encounter. The sealed archive matches the candidate source. Both platform exports share pack SHA256 `3d49c835ebb4cbcced18f487e4240ce75076caf56a4f7d60ae8ce52a14da9b66`; all 21,169 packed assets matched. Actual Linux checks passed for movement, save/load/restart, captain pickup, Aloe harvesting and Jungle resume from the earned campaign save. Aloe and final Jungle screenshots were inspected. The captain and Aloe interaction checks use supplied checkpoints; the campaign route uses linked earned saves.

R10's two failures were outdated route expectations; the failed evidence is retained. R11 includes corrected expectations and the harvest timer-boundary fix.

This verifies the implemented route and prepared Linux package, not every original interaction. Prism/Reaver/Amber/Net and Cave Stone/Manafoil are later work, outside these binaries. The Manafoil shaft requires a missing floor-lift mechanism before its access/escape can be accepted. Remaining content, clean-machine preparation, native Windows execution, representative GPU/audio checks and owner acceptance remain open. Original assets and personal saves are not published.
