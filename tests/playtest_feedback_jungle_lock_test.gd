extends SceneTree
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 8: await process_frame
	if not check(is_instance_valid(jungle.drunk), "Jungle actor fixture missing"): return
	# Supply the existing actor's hold state to exercise the real host input gate, without claiming a walked dialogue.
	jungle.drunk.state.hold = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not check(not paused and jungle.actor_input_locked(), "Fixture did not lock live Jungle input"): return
	var feedback = root.get_node("PlaytestFeedback")
	key(KEY_F10)
	if "--expect-blocked" in OS.get_cmdline_user_args():
		if not check(not feedback.active and not paused, "Expected original locked host to consume F10"): return
		print("PASS baseline reproduces F10 blocked by unpaused Jungle actor input lock")
		quit(0); return
	if not check(feedback.active and paused and not feedback.prior_paused, "F10 blocked during live actor input lock"): return
	if not check(feedback.pending.diagnostics.area == "Jungle", "Wrong captured area"): return
	key(KEY_ESCAPE)
	if not check(not feedback.active and not paused and jungle.actor_input_locked(), "Closing report lost actor lock or restored wrong pause"): return
	print("PASS live Jungle actor lock permits F10 reporting and is preserved on close (supplied hold state)")
	quit(0)
