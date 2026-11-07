extends SceneTree
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new(); event.keycode = code; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events()
func exercise(owner: Node, label: String) -> bool:
	var feedback = root.get_node("PlaytestFeedback")
	if not check(owner.active() and not paused, label+" fixture inactive"): return false
	key(KEY_F10)
	if "--expect-blocked" in OS.get_cmdline_user_args():
		return check(not feedback.active and not paused, label+" original handler unexpectedly passed F10")
	if not check(feedback.active and paused and not feedback.prior_paused, label+" swallowed F10"): return false
	key(KEY_ESCAPE)
	return check(not feedback.active and not paused and owner.active(), label+" lost active state on cancel")
func run() -> void:
	# Real hosts with supplied active flags; checks event routing, not walked cutscene entry.
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 8: await process_frame
	jungle.departure.state().phase = "movie"
	if not exercise(jungle.departure, "departure"): return
	jungle.departure.state().phase = "idle"
	jungle.exit_encounter.movie.phase = "playing"
	if not exercise(jungle.exit_encounter, "exit movie"): return
	jungle.exit_encounter.movie.phase = "none"
	current_scene = null; jungle.queue_free(); await process_frame
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 8: await process_frame
	hive.runes.checkpoint.room = "RUNES"
	if not exercise(hive.runes, "rune room"): return
	hive.runes.checkpoint.room = ""
	print("PASS F10 routing through three active real overlay handlers (supplied states); baseline=", "--expect-blocked" in OS.get_cmdline_user_args())
	quit(0)
