extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(240):
		await process_frame
		if scene.walkthrough_ready: break
	for i in range(30): await physics_frame
	assert(scene.indexed_chain.strike())
	await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var location: Vector3 = scene.player.global_position
	var elapsed: float = scene.indexed_chain.state.elapsed
	scene.interaction_requested = true
	scene._open_video_review()
	var overlay = scene.video_overlay
	assert(paused and not scene.interaction_requested)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	scene._open_video_review()
	assert(scene.video_overlay == overlay)
	await create_timer(0.5).timeout
	assert(overlay.review.video.stream_position > 0)
	assert(scene.player.global_position == location)
	assert(scene.indexed_chain.state.elapsed == elapsed)
	overlay.review.play_clip(1)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	assert(not paused and not is_instance_valid(overlay))
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	for i in range(3): await physics_frame
	assert(scene.indexed_chain.state.elapsed > elapsed)
	# Restore an already-paused scene and released mouse, including external removal.
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene._open_video_review()
	assert(paused)
	scene.video_overlay.queue_free()
	await process_frame
	await process_frame
	assert(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	paused = false
	print("Video overlay passed: playback while world paused, pending input cleared, duplicate guard, Escape return, event resumes, prior pause/mouse restored")
	scene.free()
	quit()
