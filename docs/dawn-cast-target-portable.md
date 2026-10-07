# Dawn non-null cast target preparation

The original A8270..A839C selects direct, special-kind5 or remembered-position routing before effect dispatch. Indirect aim uses remembered horizontal coordinates but current target height; distance minus target radius clears indirect mode only when strictly negative. Indirect mode consumes a0..63 random return to update flag bit27. It saves the prior heading and assigns the prepared bearing shifted by8.

192 original-instruction comparisons pass. Geometry, target virtuals and RNG/heading returns are supplied at inspected call boundaries; SETNE after the b6 bit2 test is modeled explicitly. The separate integer heading component has612 actual native comparisons; `prepare_with_heading` connects it to the prepared horizontal position.

Run `godot --headless --path . --script res://tests/dawn_cast_target_test.gd`. Original media are not required.

This component covers non-null targets. Targetless casts, effect constructors, target acquisition and live owner/health dispatch remain unfinished. Staged outside main while the240-test suite is running; main integration pending the source freeze ending.
