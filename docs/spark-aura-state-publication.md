# Saved maximum-charge Spark state

This publishes the restoration-owned state model for the maximum-charge Spark aura: additive fixed-point duration, reproducible bolt-level selection, pulse accounting, and validated saved homing bolts. It contains no original game payloads or personal saves.

The local implementation also connects Ancient Stone consumption, maximum-charge casting, combat protection, gradual recovery, magic rewards and area transport. Those scene controllers and their asset-dependent integration test are not part of this standalone publication.

The source behavior distinguishes the aura (effect24) from its individual level0–3 bolts (effects20–23). Each admitted recast adds600 to the timer's high word. The live conversion of60 ticks/second, one-second pulses and the saved LCG are explicit provisional adapters; this module does not establish original clock or RNG parity.

Run the exact published state checks without game assets:

```sh
flatpak run org.godotengine.Godot --headless --path . --script res://tests/player_spark_aura_state_test.gd -- --state-only
```

Verified with exit0 in an isolated checkout on2026-09-28. Checks cover timer extension/expiry, frame partitioning, all four bolt levels, JSON canonicalization and malformed packet rejection. Without `--state-only`, the local development project additionally checks preservation through its magic reward controller, which is not published here.

Full Act One and original presentation remain open.
