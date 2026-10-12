extends StaticBody3D
## Development collision hull from the displayed source door geometry.
## Shapes follow sampled poses; native swept motion/pushing is not implemented.
var door: Node3D
var collider: CollisionShape3D
var shapes: Dictionary = {}
var cached_basis := Basis.IDENTITY

func bind(source: Node3D) -> void:
	assert(door == null and source.opening_percent >= 0)
	door = source
	collision_layer = 1
	collision_mask = 0
	# Bake reflected/scaled source axes into vertices; physics body keeps unit scale.
	top_level = true
	collider = CollisionShape3D.new()
	add_child(collider)
	cached_basis = door.global_basis
	door.opening_changed.connect(_sync_pose)
	_sync_pose(door.opening_percent)

func _shape_at(percent: int) -> ConvexPolygonShape3D:
	if not cached_basis.is_equal_approx(door.global_basis):
		shapes.clear()
		cached_basis = door.global_basis
	if not shapes.has(percent):
		var points := PackedVector3Array()
		for vertex in door.pose_points(percent):
			points.append(door.global_basis * vertex)
		var hull := ConvexPolygonShape3D.new()
		hull.points = points
		shapes[percent] = hull
	return shapes[percent]

func _sync_pose(percent: int) -> void:
	global_transform = Transform3D(Basis.IDENTITY, door.global_position)
	collider.shape = _shape_at(percent)

func move_toward(target: int, player: CharacterBody3D = null) -> bool:
	# Conservative hull between adjacent sampled poses, not native pushing/crushing.
	target = clampi(target, 0, 100)
	while door.opening_percent != target:
		var current: int = door.opening_percent
		var next := current + (1 if target > current else -1)
		if player != null:
			var swept := ConvexPolygonShape3D.new()
			var points := _shape_at(current).points
			points.append_array(_shape_at(next).points)
			swept.points = points
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = swept
			query.transform = Transform3D(Basis.IDENTITY, door.global_position)
			query.collision_mask = 2
			query.margin = 0.003 * door._unit_scale * 64.0
			for hit in get_world_3d().direct_space_state.intersect_shape(query):
				if hit.collider == player:
					return false
		door.set_opening(next)
	return true
