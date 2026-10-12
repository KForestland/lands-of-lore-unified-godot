extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(300):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready)
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for pose in [Vector3(-63,-263,-18599), Vector3(-90,-263,-18615), Vector3(-63,-200,-18615), Vector3(-63,-263,-17741)]:
		scene.player.global_position = pose + scene.native_translation
		scene._check_chamber_arrival()
		assert(scene.chamber_arrival_state == "not_started")
	scene.player.global_position = Vector3(-63,-263,-18615) + scene.native_translation
	scene.flying = true
	scene._check_chamber_arrival()
	assert(scene.chamber_arrival_state == "not_started")
	scene.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene._check_chamber_arrival()
	assert(scene.chamber_arrival_state == "not_started")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.player.global_position = Vector3(-63,-263,-18590) + scene.native_translation
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	scene.set_physics_process(true)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(120):
		await physics_frame
		if scene.chamber_arrival_state == "playing": break
	key.pressed = false
	Input.parse_input_event(key)
	assert(scene.chamber_arrival_state == "playing" and paused)
	await create_timer(0.5).timeout
	assert(scene.video_overlay.review.video.stream_position > 0)
	scene.video_overlay.review.close()
	await process_frame
	await process_frame
	assert(not paused and scene.chamber_arrival_state == "complete")
	scene._check_chamber_arrival()
	assert(not is_instance_valid(scene.video_overlay))
	print("Chamber trigger passed: approach/side/height/bridge exclusions, flight/mouse guards, real playback, skip and no repeat")
	scene.free()
	quit()
