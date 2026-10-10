extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var state = preload("res://scripts/lol2/river_drowning_state.gd").new()
	state.advance(11.9,true)
	assert(not state.dead)
	state.advance(5.0,true,false)
	assert(is_equal_approx(state.elapsed,11.9))
	state.advance(0.1,false)
	assert(state.elapsed == 0 and not state.active)
	state.advance(12.0,true)
	assert(state.dead)
	state.advance(0.0,false)
	assert(state.dead)
	state.reset()
	assert(not state.dead)
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(300):
		await process_frame
		if is_instance_valid(scene.river_chains): break
	for i in range(5): await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert(not scene.river_water.submerged(Vector3(-65,-258,-17050)))
	assert(not scene.river_water.submerged(Vector3(-65,-263,-18615)))
	scene.player.global_position = Vector3(-65,-363,-17050)+scene.native_translation
	for i in range(20): await physics_frame
	assert(scene.drowning.active and scene.drowning.elapsed > 0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var before: float = scene.drowning.elapsed
	await create_timer(0.3).timeout
	assert(is_equal_approx(before,scene.drowning.elapsed))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/chamber_route_20260913/drowning.png") == OK)
	for i in range(900):
		await physics_frame
		if scene.drowning.dead: break
	assert(scene.drowning.dead and is_equal_approx(scene.drowning.elapsed,12.0))
	assert(not scene.drowning_menu.visible)
	var camera_before: Vector3 = scene.camera.position
	var position: Vector3 = scene.player.global_position
	for i in range(5): await physics_frame
	assert(scene.player.global_position == position and not scene.interaction_available)
	assert(scene.camera.position.y < camera_before.y)
	paused = true
	var sink_before: float = scene.drowning_sink_elapsed
	await create_timer(0.2, true).timeout
	assert(is_equal_approx(scene.drowning_sink_elapsed, sink_before))
	paused = false
	for i in range(180):
		await physics_frame
		if scene.drowning_menu.visible: break
	assert(scene.drowning_menu.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	assert(scene.drowning_reload.has_focus())
	assert(is_equal_approx(scene.camera.position.y, camera_before.y - scene.DROWNING_SINK_DEPTH))
	assert(not scene.drowning_notice.visible)
	assert(not scene._quickload("user://missing_drowning_test.json").is_empty())
	assert(scene.drowning.dead and scene.drowning_menu.visible)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/chamber_route_20260913/drowning_reload.png") == OK)
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	assert(not scene.drowning.dead and scene.drowning.elapsed == 0)
	assert(scene.player.global_position.distance_to(position) > 100)
	assert(not scene.drowning_notice.visible and not scene.drowning_menu.visible)
	assert(scene.camera.position.is_equal_approx(camera_before))
	scene._jump_checkpoint(13)
	var save_path := "user://drowning_recovery_test.json"
	assert(scene._quicksave(save_path).is_empty())
	var saved_position: Vector3 = scene.player.position
	scene.drowning_camera_origin = scene.camera.position
	scene.drowning.advance(12.0,true)
	scene._advance_drowning_death(2.0)
	assert(scene.drowning_menu.visible)
	assert(scene._quickload(save_path).is_empty())
	assert(not scene.drowning.dead and not scene.drowning_menu.visible)
	assert(scene.player.position.is_equal_approx(saved_position))
	assert(scene.camera.position.is_equal_approx(scene.drowning_camera_origin))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("River drowning passed:12-second deadline, exit reset, terminal death, real river exposure, mouse pause, frozen player, sinking camera, paused animation, reload menu, failed-load retention and Enter checkpoint return and successful quicksave recovery")
	scene.free()
	quit()
