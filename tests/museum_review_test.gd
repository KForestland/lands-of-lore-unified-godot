extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var scene = load("res://scenes/lol2/museum_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.ready_for_review and scene.face_count > 5000)
	assert(scene.materials.size() > 10)
	assert(scene.museum_props.instances.size() == 102)
	for i in range(scene.museum_props.records.size()):
		var record: Dictionary = scene.museum_props.records[i]
		var instance: MeshInstance3D = scene.museum_props.instances[i]
		assert(instance.position == Vector3(record.position[0], record.position[1], record.position[2]))
		assert(instance.mesh.size == Vector2(record.right - record.left, record.top - record.bottom))
	assert(scene.museum_props.animations.size() == 2)
	await create_timer(0.3).timeout
	assert(scene.museum_props.animations[0].frame > 0)
	paused = true
	var held: float = scene.museum_props.animation_time
	await create_timer(0.3).timeout
	assert(scene.museum_props.animation_time == held)
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene.reset_position()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.ROOT + "museum.json"))
	assert(data.boundary_bindings.size() == 1028)
	for i in range(120): await physics_frame
	assert(scene.player.is_on_floor(), "Arrival capsule must settle on original floor")
	assert(absf(scene.player.position.y - 32) < 0.2)
	assert(scene.resets == 0)
	var query := PhysicsRayQueryParameters3D.create(Vector3(-3796, 80, -369), Vector3(-3796, -20, -369))
	query.exclude = [scene.player.get_rid()]
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and absf(hit.position.y) < 0.01, "Source arrival floor must be at zero")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_capture_20260913/godot_museum_review.png") == OK)
	var before: Vector3 = scene.player.position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(60): await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(scene.player.position.distance_to(before) > 10, "Arrival must allow walking into passage")
	assert(scene.player.is_on_floor() and scene.resets == 0)
	scene.reset_position()
	for i in range(60): await physics_frame
	assert(scene.player.is_on_floor() and scene.player.position.distance_to(before) < 0.2, "Reset position: %s before: %s grounded: %s" % [scene.player.position, before, scene.player.is_on_floor()])
	print("Museum review passed: mesh/material load, capsule arrival support, source floor ray, actual W movement and reset")
	scene.free()
	quit()
