extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(300):
		await process_frame
		if is_instance_valid(scene.bridge_warning): break
	assert(is_instance_valid(scene.bridge_warning))
	var cue = scene.bridge_warning
	assert(cue.voice.stream != null)
	assert(is_equal_approx(cue.voice.stream.get_length(), 70910.0/22050.0))
	scene.set_process_unhandled_input(false) # Desktop mouse cannot steer test.
	scene.player.global_position = Vector3(-65,-258,-16790)+scene.native_translation
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in range(5): await physics_frame
	assert(not cue.played)
	scene.flying = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in range(5): await physics_frame
	assert(not cue.played)
	scene.flying = false
	assert(not cue.bounds.has_point(Vector3(-65,-363,-16790)))
	assert(not cue.bounds.has_point(Vector3(-65,-263,-18615)))
	scene.player.global_position = Vector3(-65,-250,-16690)+scene.native_translation
	for i in range(8): await physics_frame
	assert(not cue.played)
	var start: Vector3 = scene.player.global_position
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(100):
		await physics_frame
		if cue.played: break
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	assert(cue.played and cue.subtitle.visible)
	assert(cue.voice.playing)
	await create_timer(0.2).timeout
	assert(cue.voice.get_playback_position() > 0)
	var finished_count := [0]
	cue.voice.finished.connect(func(): finished_count[0] += 1)
	assert(scene.player.global_position.distance_to(start) > 10)
	assert(scene.resets == 0)
	assert(cue.subtitle.text == "Hey, you!")
	var remaining: float = cue.remaining
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(0.2).timeout
	assert(is_equal_approx(cue.remaining,remaining))
	assert(cue.voice.stream_paused)
	var audio_before: float = cue.voice.get_playback_position()
	await create_timer(0.2).timeout
	assert(is_equal_approx(cue.voice.get_playback_position(),audio_before))
	paused = true
	await create_timer(0.2,true).timeout
	assert(is_equal_approx(cue.remaining,remaining))
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await create_timer(0.15).timeout
	assert(not cue.voice.stream_paused)
	paused = true
	await process_frame
	assert(cue.voice.stream_paused)
	# Allow the already queued audio mix block to settle before measuring hold.
	await create_timer(0.1,true).timeout
	audio_before = cue.voice.get_playback_position()
	await create_timer(0.2,true).timeout
	assert(is_equal_approx(cue.voice.get_playback_position(),audio_before))
	paused = false
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/chamber_route_20260913/bridge_warning.png") == OK)
	for i in range(240):
		await physics_frame
		if not cue.subtitle.visible: break
	assert(not cue.subtitle.visible and cue.remaining == 0)
	await create_timer(0.2).timeout
	assert(not cue.voice.playing and finished_count[0] == 1)
	# Re-entry and checkpoint recovery must not replay the bluff.
	scene.player.global_position = Vector3(-65,-258,-16937)+scene.native_translation
	for i in range(5): await physics_frame
	scene.player.global_position = Vector3(-65,-258,-16790)+scene.native_translation
	for i in range(5): await physics_frame
	assert(cue.played and not cue.subtitle.visible and not cue.voice.playing)
	# Recovery must interrupt any active voice as well as the subtitle.
	cue.voice.play()
	assert(cue.voice.playing)
	scene._reset()
	assert(cue.played and not cue.subtitle.visible and not cue.voice.playing)
	assert(scene.river_deck.chain_rule.counts.is_empty())
	assert(scene.chamber_arrival_state == "not_started")
	print("Bridge warning passed: actual W entry, original voice playback/finish and one-time subtitle, no flight/mouse/riverbed trigger, audio pause, expiry, interrupted recovery, no replay after re-entry/reset, bridge/chamber state unchanged")
	scene.free()
	quit()
