# Saved projectile movement

Both local Dawn hosts expose `move_projectile(id, world_delta, radius)`. The store composes the verified planar-distance and spell32 motion helpers with the existing quantized sine table. The host sweeps the result through live Godot physics, then commits its fixed-point position. Rejected/stale movement commits leave the saved effect unchanged. Contact metadata is transient and is not serialized.

The caller supplies the shared clock delta, effect radius and lifecycle ordering. No new wall clock or periodic attack timer is introduced. The owner must process the lifecycle update (including child creation/retirement) before moving a surviving fireball. AI creation, scheduler invocation, collision-to-native-event mapping, actual health dispatch and presentation remain open.

Collision is a modern swept-sphere adapter. Initial overlap is checked separately, then `cast_motion` supplies the safe fraction; contact metadata is queried at the unsafe fraction. A0.01 margin fallback helps identify numerical boundary contacts without advancing accepted motion. See the [Godot direct-space API](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate3d.html). This does not establish native collision parity or exact precision across Godot world coordinates.

Validation: three source-stable headless tests (original motion, saved ownership and actual physics) and three source-stable rendered checks (both production host movement/save paths, Hive encounter, Jungle encounter). Physics coverage includes a swept blocker, caster exclusion, initial overlap, zero motion,100-unit movement from a supplied delta, JSON persistence and stale commit rejection. Host tests supply allocation/getter inputs; they are not AI-driven combat. [Evidence](dawn-projectile-motion-checks.json).

The [host patch](../patches/dawn-projectile-motion-binding.patch) targets the full local host after the earlier launch/save bindings. Original media and full host dependencies remain outside this component PR. Asset-free test: `godot --headless --path . --script res://tests/dawn_projectile_world_test.gd`.
