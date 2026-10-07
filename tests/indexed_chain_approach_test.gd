extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for frame in range(240):
		await process_frame
		if scene.walkthrough_ready:
			break
	assert(scene.walkthrough_ready)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await physics_frame
	assert(scene._position_chain_approach(), "Native capsule must fit source region800")
	assert(scene.indexed_doors.size() == 2)
	for opening in [0, 50, 100, 0]:
		for door in scene.indexed_doors:
			door.set_opening(opening)
			for face in range(4):
				var surface: MeshInstance3D = door.get_child(face)
				assert(surface.layers == 2 and surface.material_override is ShaderMaterial)
				var copies := 0
				for pair in scene.occluder_pairs + scene.light_pairs:
					if pair[0] == surface:
						assert(pair[1].mesh == surface.mesh)
						assert(pair[1].global_transform.is_equal_approx(surface.global_transform))
						copies += 1
				assert(copies == 2, "Each door face has synchronized occlusion and light copies")
			assert(door.get_child(4).collider.shape != null)
	var expected: Vector3 = Vector3(1169.5, -215, -11580) + scene.native_translation
	assert(Vector2(scene.player.position.x - expected.x, scene.player.position.z - expected.z).length() < 0.01)
	for frame in range(60):
		await physics_frame
	assert(scene.player.is_on_floor(), "Native player settles on original floor")
	assert(absf(scene.player.position.y - expected.y - 32) < 0.2)
	var prop_found := false
	for prop in scene.props_root.get_children():
		if prop.get_meta("original_record", -1) == 1056:
			prop_found = true
	assert(prop_found, "Live-verified nonblocking prop already belongs to indexed cave")
	assert(scene.indexed_chain.can_strike(), "Native approach must reach and aim at chain")
	assert(scene.indexed_chain.strike())
	assert(not scene.indexed_chain.strike())
	for frame in range(280):
		await physics_frame
	assert(scene.indexed_chain.state.door_dispatch_count == 1)
	for door in scene.indexed_doors:
		assert(door.opening_percent == 100)
	for pair in scene.occluder_pairs + scene.light_pairs:
		if pair[0] == scene.indexed_chain.mesh:
			assert(pair[1].material_override.get_shader_parameter("indices") == scene.indexed_chain.textures[28])
	scene.set_physics_process(false)
	var safe_position: Vector3 = scene.player.global_position
	var door_center := Vector3.ZERO
	var guarded_door = scene.indexed_doors[0]
	var points: PackedVector3Array = guarded_door.pose_points(0)
	for point in points:
		door_center += guarded_door.to_global(point) / points.size()
	scene.player.global_position = door_center
	await physics_frame
	await physics_frame
	scene.indexed_chain.reset()
	scene.indexed_chain.tick(0)
	assert(scene.indexed_chain.waiting and guarded_door.opening_percent > 0, "Native capsule stops closing door")
	scene.player.global_position = safe_position
	await physics_frame
	await physics_frame
	scene.indexed_chain.tick(0)
	assert(not scene.indexed_chain.waiting)
	scene.set_physics_process(true)
	for frame in range(3):
		await physics_frame
	for door in scene.indexed_doors:
		assert(door.opening_percent == 0)
	assert(scene.indexed_chain.rule.remaining == 2)
	print("Indexed chain approach: native coordinate placement, capsule clearance, grounding source prop and both indexed doors across four poses, reachable strike, duplicate guard, animation sync, both-door opening and reset passed")
	scene.free()
	quit()
