# Projectile launch placement

`dawn_projectile_launch.gd` preserves the AF4A8 launch placement decisions needed by Dawn’s spell32 constructor. It projects by caster radius + effect radius +1, uses the supplied absolute launch-height getter minus half sprite height, tries the projected region, falls back to the caster XY when that region placement fails, and runs collision admission only after successful region placement. A collision rejection still leaves heading, speed and flags initialized; failure of both placements preserves their earlier values.

The owner supplies the bearing, sine/cosine samples and world-query outcomes. `placement_requests` records the exact ordered points those results describe. This component does not query Godot physics or create a live projectile. Original non-null-target launch bearing uses the floating-point atan path; it must not silently reuse the integer cast-heading approximation.

Validation:288 executions of original AF4A8 plus93AE4 compared with Godot, covering projection, origin fallback, double placement failure, collision admission, six headings and signed coordinate wrap. Virtual height/radius getters and region/collision query returns are supplied. Global collision scratch save/clear/restore calls are intercepted. The rotation table is the existing host-x87 reconstruction; equivalence with an original runtime table remains open. The replay covers the null-point bearing branch; targeted atan evaluation remains open.

Run `godot --headless --path . --script res://tests/dawn_projectile_launch_test.gd`. The initial test comparison failed on JSON float versus integer container types; the corrected comparison normalizes only JSON numeric representation. The final source-stable run passed. No live Dawn combat completion is claimed.
