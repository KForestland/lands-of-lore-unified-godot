# Dawn casting components

These components preserve the original admission, candidate scan, cast-completion tail, shield/heal transitions, active-spell expiry and planar distance arithmetic. They are staged for live integration; this is not a completed hostile Dawn encounter.

Run these without original media, using `godot --headless --path . --script res://tests/NAME.gd`:

- `dawn_cast_entry_test`:700 native frame-event/cast-entry boundaries. Rechecks admission silently, clears indirect-target state before admission, rejects zero choice immediately, and rotates the next selection after the event even when casting fails. Apply entry flags before effect dispatch, then call `finish_event` with the actual post-dispatch flags.
- `dawn_admission_test`:240 native cases.
- `dawn_ai_decision_test`:280 composed native decisions through goal/action/spell scoring and admission, including disabled-AI and zero-mana gates, preserved diagnostic fields, explicit RNG-consumption reporting and JSON-restored inputs. Effective stats/world context remain caller-supplied; no cast dispatch or AI commit.
- `dawn_spell_scoring_test`:228 native comparisons using the original parsed Dawn profile plus synthetic signed-weight boundaries. Reuses goal/action arithmetic; returns all positive candidates in original order.
- `dawn_selection_test`:588 six-candidate scans plus480 scans with changing candidate lists (three to six spells) and count-dependent RNG bounds. The six-spell default preserves the earlier Recover fixture; live callers must pass the scorer output.
- `dawn_cast_completion_test`:3024 tails, including spell32 allocation/constructor failures. Original dispatch can still debit resources on those failures.
- `dawn_temporary_effects_test`:384 shield updates,28 frame callbacks,432 completed heal cycles.
- `dawn_active_spells_test`:682 expiry cases, preserving original byte-count compaction and separate index/pointer advancement.
- `dawn_object_distance_test`:1284 two-object cases plus1536 prior startup-distance cases.

Use the existing shared world clock: status_gate drives active-list maintenance; fixed drives effect lifetime; delta drives projectile movement. Distances preserve startup53-bit nearest-even arithmetic. A stored spell choice is not proof that admission succeeded; a failed effect allocation is not automatically a reason to skip the original cast-completion tail.

Live condition producers, scorer invocation, actor invocation, effect construction/dispatch, animation, mitigation binding, health scaling, presentation and save ownership still require integration. The main campaign source was held unchanged during its fresh run. Original assets stay local. Full Act1 and Bob acceptance remain open.
