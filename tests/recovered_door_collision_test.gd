extends SceneTree
const Door = preload("res://scripts/lol2/recovered_door.gd")
const Player = preload("res://scripts/lol2/chain_walk_player.gd")
const Collision = preload("res://scripts/lol2/recovered_door_collision.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/doors/motion.json"))
	for record in data.doors:
		var door := Door.new()
		root.add_child(door)
		door.configure(record, 1.0 / 64.0)
		door.position = Vector3(10, 100, -20)
		door.scale.z = -1
		var body := Collision.new()
		door.add_child(body)
		body.bind(door)
		var closed_center := Vector3.ZERO
		for p in body.collider.shape.points:
			closed_center += p
		closed_center /= body.collider.shape.points.size()
		closed_center += body.global_position
		var space := door.get_world_3d().direct_space_state
		var probe := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.125
		capsule.height = 0.75
		probe.shape = capsule
		probe.transform.origin = closed_center
		probe.collision_mask = 1
		for frame in [0, 50, 100, 0]:
			door.set_opening(frame)
			await physics_frame
			await physics_frame
			assert(body.global_basis.is_equal_approx(Basis.IDENTITY))
			# Every hull vertex matches the displayed source geometry in world space.
			var n := 0
			for face in range(4):
				var surface: MeshInstance3D = door.get_child(face)
				for v in surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					assert(body.to_global(body.collider.shape.points[n]).is_equal_approx(surface.to_global(v)))
					n += 1
			var hits := space.intersect_shape(probe)
			if frame != 50:
				assert((not hits.is_empty()) == (frame == 0), "Player capsule must clear the old doorway center when fully open")
		var player := Player.new()
		root.add_child(player)
		player.set_physics_process(false)
		player.active = true
		# Choose the broad face normal from its source horizontal edge.
		var vertices := door.pose_points(0)
		var edge: Vector3 = door.global_basis * (vertices[1] - vertices[0])
		if Vector2(edge.x, edge.z).length() < 0.1:
			edge = door.global_basis * (vertices[2] - vertices[1])
		var normal := Vector3(-edge.z, 0, edge.x).normalized()
		assert(normal.length() > 0.9)
		var crossing := closed_center + edge.normalized() * 0.22
		for opening in [0, 100]:
			door.set_opening(opening)
			await physics_frame
			await physics_frame
			for side in [-1, 1]:
				player.position = crossing + normal * 0.35 * side - Vector3.UP * 0.375
				for step in range(35):
					player.move_and_collide(-normal * 0.02 * side)
				var progress: float = (player.position + Vector3.UP * 0.375 - crossing).dot(normal) * side
				assert(progress > 0.1 if opening == 0 else progress < -0.3, "Closed door blocks traversal; open door permits crossing both ways")
		# Reset/closing stops before reaching a player standing in the doorway.
		player.position = closed_center - Vector3.UP * 0.375
		await physics_frame
		await physics_frame
		assert(not body.move_toward(0, player))
		assert(door.opening_percent > 0)
		var held: int = door.opening_percent
		await physics_frame
		await physics_frame
		assert(space.intersect_shape(probe).is_empty(), "Stopped panel leaves capsule clear")
		assert(not body.move_toward(0, player) and door.opening_percent == held)
		player.position += Vector3.UP * 10
		await physics_frame
		await physics_frame
		assert(body.move_toward(0, player) and door.opening_percent == 0)
		# A player in the opening arc must stop even a single 0 -> 100 request.
		door.set_opening(50)
		var arc_center := Vector3.ZERO
		for point in body.collider.shape.points:
			arc_center += point
		arc_center /= body.collider.shape.points.size()
		player.position = door.global_position + arc_center - Vector3.UP * 0.375
		door.set_opening(0)
		await physics_frame
		await physics_frame
		assert(not body.move_toward(100, player) and door.opening_percent < 50)
		player.position += Vector3.UP * 10
		await physics_frame
		await physics_frame
		assert(body.move_toward(100, player))
		player.free()
		door.free()
	print("Door collision: both mirrored doors, four poses, world hull agreement, bidirectional traversal, guarded opening/closing, clearance retry and reset passed")
	quit()
