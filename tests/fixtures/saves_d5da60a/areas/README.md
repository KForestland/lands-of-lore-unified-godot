# Fifteen pre-foundation area formats

All fifteen `<AREA>.json` files were written by the actual legacy hosts in a detached, staged, owned d5da60a worktree before Plan3 changes. The captures are quiescent initial scenes, not earned progress. Source, scenes, versions, SHA256 and native-bank size measurements are in manifest.json. Cave v1 is the exact inverse of the existing 1->2 reader migration, verified by that unchanged reader. The earlier five Plan1 witnesses are untouched.

`*_roundtrip.json` files pin raw writer output after loading each d5 packet on the qualified Plan2 stack, before Plan3 changes. Legacy loaders normalize some optional state, so this is the byte comparison used during extraction of area_snapshot. Do not regenerate these to make a change pass. Legacy files contain no native_bank: that loss is the F-07 baseline, not the new whole-game-save acceptance.
