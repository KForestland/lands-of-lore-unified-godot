# Projectile impact ownership

`dawn_projectile_store.impact(id, collision, target, collision_heading)` measures planar travel from the saved constructor origin to the committed sweep position, then invokes the verified contact transition. It rejects contradictory wall/actor identities before changing saved state. Contact state is committed before returning a damage request.

Four source-stable checks pass: original contact fixtures, persistent ownership, actual Godot swept collisions, and original planar distance fixtures. The composed physics check proves positive-distance wall impact creates its explosion child before parent retirement; the same physical hit mapped to an actor requests direct damage once, including across a JSON reload. Invalid mapped collisions leave state unchanged. [Evidence](dawn-projectile-impact-checks.json).

The collision producer still supplies actor/wall classification, stable target identity and native collision bearing. This method does not infer original collision bearing from a Godot normal or guess actor identity. Production identity/bearing binding, health-context construction/dispatch, automatic cast scheduling and presentation remain open.

Run `godot --headless --path . --script res://tests/dawn_projectile_world_test.gd` for the asset-free physics/ownership composition.
