extends SceneTree
## Walking view is drawn at render rate: with the physics tick slower than the frame rate (as on a display faster
## than 60 Hz), the indexed world camera advances on frames between ticks instead of jumping on tick frames only.
## The physics body, collision and the main camera are unchanged; teleports and idle frames are not shifted.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for frame in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	assert(cave.walkthrough_ready)
	assert(is_equal_approx(cave.JUMP_SPEED, 96.0), "Cave jump launch raised to 96 (about 36 units)")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for frame in range(10): await process_frame
	# Idle: the drawn view is the physics camera.
	assert(cave.index_camera.global_transform.origin.is_equal_approx(cave.camera.global_transform.origin), "Idle view is unshifted")
	Engine.physics_ticks_per_second = 4
	Engine.max_physics_steps_per_frame = 1
	var walk := InputEventKey.new(); walk.physical_keycode = KEY_W; walk.keycode = KEY_W; walk.pressed = true
	Input.parse_input_event(walk)
	var body_moves := 0
	var view_moves := 0
	var between_tick_view_moves := 0
	var last_body: Vector3 = cave.player.global_position
	var last_view: Vector3 = cave.index_camera.global_transform.origin
	var last_tick := Engine.get_physics_frames()
	for frame in range(90):
		await process_frame
		var body: Vector3 = cave.player.global_position
		var view: Vector3 = cave.index_camera.global_transform.origin
		var ticked := Engine.get_physics_frames() != last_tick
		if body.distance_to(last_body) > 0.001: body_moves += 1
		if view.distance_to(last_view) > 0.001:
			view_moves += 1
			if not ticked: between_tick_view_moves += 1
		assert(view.distance_to(cave.camera.global_transform.origin) <= cave.WALK_SPEED / 4.0 + 0.01, "View stays within one tick of the body")
		last_body = body; last_view = view; last_tick = Engine.get_physics_frames()
	walk.pressed = false
	Input.parse_input_event(walk)
	print("body moved on %d frames, view on %d (%d between ticks)" % [body_moves, view_moves, between_tick_view_moves])
	assert(body_moves > 0 and between_tick_view_moves > 0 and view_moves > body_moves, "View advances between physics ticks")
	# Teleport: no interpolation across a reposition.
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	for frame in range(10): await process_frame
	cave.player.global_position += Vector3(200, 0, 0)
	await physics_frame
	await process_frame
	assert(cave.index_camera.global_transform.origin.is_equal_approx(cave.camera.global_transform.origin), "Teleports are not interpolated")
	print("PASS cave view smoothing: render-rate view between ticks, idle and teleport unshifted, jump 96")
	quit()
