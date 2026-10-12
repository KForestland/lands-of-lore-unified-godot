extends RefCounted
## Source D6DD9 table selection / D4670 dimensions / D6104 eye placement.
## Modern physics adapter; source transformation admission/timing is separate.
const HEIGHTS := [46.0, 69.0, 8.0]
const RADII := [15.0, 23.0, 8.0]
const EYES := [42.0, 61.0, 17.0]
# Keep the established checkpoint/save origin 32 units above the feet.
const FOOT_OFFSET := 32.0

static func valid(form: Variant) -> bool:
	return (form is int or form is float) and is_finite(float(form)) and float(form) == floorf(float(form)) and form >= 0 and form <= 2

static func shape_for(form: int) -> Shape3D:
	if form == 2:
		# A capsule cannot represent height8/radius8: Godot clamps height to16.
		var cylinder := CylinderShape3D.new()
		cylinder.radius = RADII[form]
		cylinder.height = HEIGHTS[form]
		return cylinder
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADII[form]
	capsule.height = HEIGHTS[form]
	return capsule

static func apply(body: CharacterBody3D, camera: Camera3D, form: int, check_space := true) -> bool:
	if not valid(form): return false
	var collider := body.get_child(0) as CollisionShape3D
	if collider == null: return false
	var shape := shape_for(form)
	var offset: Vector3 = Vector3.UP * (HEIGHTS[form] * 0.5 - FOOT_OFFSET)
	if check_space:
		var query := PhysicsShapeQueryParameters3D.new()
		# Grounded saves can rest a fraction below the support plane. Match the
		# mover's contact tolerance at the feet, retaining full top/side clearance.
		var contact_margin := minf(body.safe_margin,0.05) if body.is_on_floor() else 0.0
		var probe := shape.duplicate() as Shape3D
		probe.height -= contact_margin
		query.shape = probe
		query.transform = body.global_transform * Transform3D(Basis.IDENTITY, offset+Vector3.UP*contact_margin*0.5)
		query.collision_mask = body.collision_mask
		query.exclude = [body.get_rid()]
		if not body.get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return false
	collider.shape = shape
	collider.position = offset
	camera.position.y = EYES[form] - FOOT_OFFSET
	return true
