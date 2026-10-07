# Dawn spell dispatch planning

The six original Dawn switch bodies now have a shared dispatch planner. It preserves constructor argument order, restores heading for spells39/40/50, sets the exclusive slot for39/40 before allocation success, and reaches the cast-completion tail whether allocation or the constructor succeeds or fails. The returned constructor arguments use symbolic instance/owner/target/alternate bindings for the future live effect owner.

192 original-instruction comparisons cover all six spells, allocation success/failure, constructor return success/failure, headings and prior exclusive flags. Allocator and constructor calls are boundaries: this does not implement constructor internals, actual effect instances, collision or health writes. The caller must supply the saved-heading value from the preceding preparation; targetless scratch-value provenance remains unbound.

Run `godot --headless --path . --script res://tests/dawn_cast_dispatch_test.gd` without original media. Prepared outside main during the240-test source freeze; shared integration is pending. This is a component checkpoint, not completed live combat or a demo build.
