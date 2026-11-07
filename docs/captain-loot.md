# Captain combat loot

Captain56 now drops his source-granted Short Sword after fighting death. Original group14638 grants item identity3801747750 to the actor. Native A5411/B6B98 drains the corpse inventory into world drops; this implementation uses a documented five-active-second retirement delay and hides the corpse, preserving its defeated state. Hit-force immediate retirement is not reproduced.

The drop uses original palette-index pixels in the cave renderer, aimed/reachable/unobstructed E pickup, a persistent receipt and the existing captain sword equipment identity. Surrender rewards are unchanged. A separately validated optional loot packet preserves legacy saves and partial delay; collected loot never respawns after reload. Original source actor items remain a grant ledger. Combat revealed an existing receipt-validation bug: original item identities require32 bits, while other numeric receipt values retain16-bit bounds.

Four focused checks pass on unchanged source: actual combat loot/pause/disk/host E/Museum transfer, surrender, existing equipment transport and cave→Museum transfer. [Report](captain-loot-checks.json). Test fighting checkpoint and camera approach are supplied. Lead inspected the actual indexed-renderer screenshot. Initial parse/test-fixture and renderer issues were corrected; historical reports remain in tmp/regressions/captain_loot*.

This closes captain56 combat sword only. Other guards, Museum skeletons, Kelsrick and Dawn loot remain open. No new full-suite/campaign/build claim is made.

The actual R7 exported Linux binary also passes ordinary F9/E/F5 pickup and reload with a source-generated, collision-grounded combat checkpoint. The visible sword disappears after pickup and the taken receipt survives reload. [Package check](captain-loot-package-checks.json). This is a supplied branch fixture, not an earned campaign. No game-code changes were needed for this check; initial driver buffering and ungrounded-camera issues are preserved in private evidence.
