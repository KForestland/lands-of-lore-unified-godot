# Dawn casting components

These components preserve the original admission, candidate scan, cast-completion tail, shield/heal transitions, active-spell expiry and planar distance arithmetic. They are staged for live integration; this is not a completed hostile Dawn encounter.

Run these without original media, using `godot --headless --path . --script res://tests/NAME.gd`:

- `dawn_admission_test`:240 native cases.
- `dawn_selection_test`:588 scans with prior choice and rotation; supplied Recover-profile scores.
- `dawn_cast_completion_test`:3024 tails, including spell32 allocation/constructor failures. Original dispatch can still debit resources on those failures.
- `dawn_temporary_effects_test`:384 shield updates,28 frame callbacks,432 completed heal cycles.
- `dawn_active_spells_test`:682 expiry cases, preserving original byte-count compaction and separate index/pointer advancement.
- `dawn_object_distance_test`:1284 two-object cases plus1536 prior startup-distance cases.

Use the existing shared world clock: status_gate drives active-list maintenance; fixed drives effect lifetime; delta drives projectile movement. Distances preserve startup53-bit nearest-even arithmetic. A stored spell choice is not proof that admission succeeded; a failed effect allocation is not automatically a reason to skip the original cast-completion tail.

Live condition/score producers, actor invocation, effect construction/dispatch, animation, mitigation binding, health scaling, presentation and save ownership still require integration. The main campaign source was held unchanged during its fresh run. Original assets stay local. Full Act1 and Bob acceptance remain open.
