extends SceneTree
## --hold-after-load (load_hold.gd): a loaded save stays paused at its spot with the hint shown, Luther does not move,
## mouse look turns him while held, and the first key press releases the game. Rendered (mouse capture, frames).
const PATH := "user://tests/load_hold/save.json"
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	printerr("FAIL load hold: ", message)
	quit(1)
func run() -> void:
	var Save = load("res://scripts/lol2/game_save.gd")
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	if not cave.walkthrough_ready: return fail("Cave not ready")
	var doc: Dictionary = Save.make_document(cave, Save.AUTOSAVE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests/load_hold"))
	var error: String = Save.write_document(PATH, doc)
	if not error.is_empty(): return fail("write: " + error)
	# Through the real path: the gate's load_bundle with --hold-after-load (registry args) attaches the hold node.
	var exe := OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
	if exe.is_empty(): return fail("LOL2_ORIGINAL_GAME_EXE unset")
	if not "--hold-after-load" in OS.get_cmdline_user_args(): return fail("registry must pass --hold-after-load")
	cave.queue_free(); current_scene = null
	await process_frame
	var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
	gate.settings_path = "user://tests/load_hold/gate_%d.cfg" % Time.get_ticks_usec()  # fresh: a remembered exe path would auto-start a new game
	root.add_child(gate); current_scene = gate
	await process_frame
	gate.path_field.text = exe
	gate.load_bundle(ProjectSettings.globalize_path(PATH))
	var hold: Node = null
	for i in 900:
		await process_frame
		hold = root.get_node_or_null("LoadHold")
		if hold != null and hold.held: break
	if hold == null: return fail("load_bundle did not attach the hold node")
	if not hold.held: return fail("hold never engaged")
	if current_scene == null or current_scene.scene_file_path != "res://scenes/lol2/cave_walkthrough.tscn": return fail("bundle did not load the Cave")
	if not paused: return fail("tree not paused while held")
	var labels: Array = hold.find_children("*", "Label", true, false)
	if labels.is_empty() or not "press any key" in str(labels[0].text): return fail("no hint shown")
	var scene = current_scene
	var start: Vector3 = scene.player.global_position
	var yaw: float = scene.player.rotation.y
	for i in 120: await process_frame
	if scene.player.global_position.distance_to(start) > 0.01: return fail("Luther moved while held")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var look := InputEventMouseMotion.new(); look.relative = Vector2(100, 0)
	Input.parse_input_event(look)
	for i in 3: await process_frame
	if absf(scene.player.rotation.y - yaw) < 0.1: return fail("mouse look did not turn Luther while held")
	var key := InputEventKey.new(); key.keycode = KEY_W; key.physical_keycode = KEY_W; key.pressed = true
	Input.parse_input_event(key)
	for i in 3: await process_frame
	key = key.duplicate(); key.pressed = false; Input.parse_input_event(key)
	if paused: return fail("key press did not release the hold")
	if is_instance_valid(hold) and hold.held: return fail("hold still active")
	print("PASS load hold: paused at the loaded spot with the hint, no movement for 120 frames, mouse look turns Luther, first key releases")
	quit(0)
