extends RefCounted
## Source D6DD9 table selection / D4670 dimensions / D6104 eye placement.
## Modern physics adapter; source transformation admission/timing is separate.
const HEIGHTS := [46.0, 69.0, 8.0]
const RADII := [15.0, 23.0, 8.0]
const EYES := [42.0, 61.0, 17.0]
# Keep the established checkpoint/save origin 32 units above the feet.
const FOOT_OFFSET := 32.0
## Owner F10 17-10-12. Godot clamps a capsule to twice its radius, so 32 is the shortest
## human capsule that keeps the stored radius 15. The hintbook prints no crouch height.
const CROUCH_HEIGHT := 32.0
const CROUCH_EYE := 28.0

static func valid(form: Variant) -> bool:
	return (form is int or form is float) and is_finite(float(form)) and float(form) == floorf(float(form)) and form >= 0 and form <= 2

static func shape_for(form: int, body_height: float = -1.0) -> Shape3D:
	var used: float = HEIGHTS[form] if body_height < 0.0 else body_height
	if form == 2:
		# A capsule cannot represent height8/radius8: Godot clamps height to16.
		var cylinder := CylinderShape3D.new()
		cylinder.radius = RADII[form]
		cylinder.height = used
		return cylinder
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADII[form]
	capsule.height = used
	return capsule

static func apply(body: CharacterBody3D, camera: Camera3D, form: int, check_space: bool = true, crouched: bool = false) -> bool:
	if not valid(form): return false
	if crouched and form != 0: return false
	var used_height: float = CROUCH_HEIGHT if crouched else HEIGHTS[form]
	var used_eye: float = CROUCH_EYE if crouched else EYES[form]
	var collider := body.get_child(0) as CollisionShape3D
	if collider == null: return false
	var shape := shape_for(form, used_height if crouched else -1.0)
	var offset: Vector3 = Vector3.UP * (used_height * 0.5 - FOOT_OFFSET)
	if check_space:
		var query := PhysicsShapeQueryParameters3D.new()
		# Grounded saves can rest a fraction below the support plane. Match the
		# mover's contact tolerance at the feet, retaining full top/side clearance.
		var restored_pose:bool=bool(body.get_meta("lol2_pose_recheck",false))
		var contact_margin := minf(body.safe_margin,0.05) if body.is_on_floor() or restored_pose else 0.0
		# The lizard is a flat-based cylinder (radius 8, height 8). On a sloped floor the rim of that base reaches into the
		# rising side of the ground (F2 Claw Mountains arrival, lead 2026-11-14: Ctrl+Q refused 'no effect here'), where
		# the human capsule's rounded base does not. For a body standing on the floor the lizard's check starts at its
		# radius above the feet (a 45-degree floor): the sides and the top keep full clearance, so a roof still refuses.
		if form == 2 and (body.is_on_floor() or restored_pose) and not crouched:
			contact_margin = maxf(contact_margin, minf(RADII[2], used_height - 1.0))
		var probe := shape.duplicate() as Shape3D
		probe.height -= contact_margin
		query.shape = probe
		query.transform = body.global_transform * Transform3D(Basis.IDENTITY, offset+Vector3.UP*contact_margin*0.5)
		query.collision_mask = body.collision_mask
		query.exclude = [body.get_rid()]
		if not body.get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return false
	body.set_meta("lol2_form", form)
	body.set_meta("lol2_crouched", crouched)
	if not check_space: body.set_meta("lol2_pose_recheck", true)
	collider.shape = shape
	collider.position = offset
	camera.position.y = used_eye - FOOT_OFFSET
	return true
