# Dawn projectile world adapter

Both local Dawn hosts now expose `query_projectile_launch(context, target)`, which connects the launch planner to the live physics space, the existing creature region graph, the host origin and the caster RID exclusion. The query is read-only with respect to encounter saves. Caster height/radius and other constructor inputs still belong to the effect owner.

`dawn_projectile_world.gd` computes targeted bearing when supplied, reuses the existing quantized sine helper, resolves projected placement before origin fallback, and queries a sphere against collision layers1/2. Coordinate conversion maps native fixed X/Y/Z to Godot X/Z/-Y plus the map origin. A source zero-radius point uses0.001 Godot extent.

These are explicit modern collision adaptations: region selection uses polygon membership and nearest floor from the creature navigation graph; it does not reproduce native AF0E0 region traversal or vertical region bounds. Sphere overlap is not the original AF9A4 collision routine. This adapter does not create or advance projectiles, apply damage, or complete Dawn combat.

Validation: two source-stable headless checks cover original launch/bearing fixtures plus actual Godot physics obstacle rejection, RID exclusion, mask filtering, region fallback/failure and translated targeted positioning. Three source-stable rendered checks cover query binding on both actual hosts, checkpoint immutability, and the existing Jungle/Hive Dawn encounter regressions. Host smoke supplies constructor height/radii and does not establish their native getter binding.

Run the asset-free adapter check with `godot --headless --path . --script res://tests/dawn_projectile_world_test.gd`. The [host patch](../patches/dawn-projectile-host-binding.patch) and rendered test target the full local host; original media and its dependency tree remain outside this component PR. [Evidence](dawn-projectile-world-checks.json).
