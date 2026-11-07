extends SceneTree
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	var scene := Node3D.new(); root.add_child(scene); current_scene = scene
	var feedback = root.get_node("PlaytestFeedback")
	var location = root.get_node("PlaytestLocation")
	location.diagnostics_enabled = true
	var inventory = load("res://scripts/lol2/museum_inventory.gd").new()
	root.add_child(inventory)
	await process_frame
	key(KEY_F10)
	if not check(feedback.active and paused, "F10 over inventory"): return
	key(KEY_I); key(KEY_F7)
	for i in 3: await process_frame
	if not check(is_instance_valid(inventory) and not inventory.closed and not location.panel_open() and paused, "typing/diagnostics escaped modal report"): return
	key(KEY_ESCAPE)
	if not check(not feedback.active and paused and inventory.is_processing_input(), "inventory state not restored"): return
	key(KEY_I)
	for i in 3: await process_frame
	if not check(not is_instance_valid(inventory) and not paused, "inventory could not close normally after report"): return
	var video = load("res://scripts/lol2/cave_video_overlay.gd").new()
	root.add_child(video)
	await create_timer(0.6).timeout
	if not check(video.review.video.is_playing(), "movie fixture not playing"): return
	key(KEY_F10)
	var at: float = video.review.video.stream_position
	await create_timer(0.6).timeout
	if not check(is_instance_valid(video) and absf(video.review.video.stream_position - at) < 0.03 and paused, "movie advanced during report"): return
	key(KEY_ESCAPE)
	if not check(not feedback.active and paused, "report lost movie pause"): return
	await create_timer(0.6).timeout
	if not check(video.review.video.stream_position > at + 0.1, "movie did not resume"): return
	video.close()
	for i in 3: await process_frame
	if not check(not paused, "movie did not restore normal game state"): return
	print("PASS: real inventory I, F7 suppression, input restoration; real movie pause/resume and prior pause preservation")
	quit(0)
