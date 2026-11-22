extends SceneTree
## G-08: F10 writes a full defect bundle. Rendered Cave, real input events (W walk, mouse look, a click), then F10 with a
## comment and Ctrl+Enter. The report folder must hold a whole-game save that validates and names the Cave, the input
## history with the walk keys and poses, frames, a log tail or a stated reason, and bundle.json with matching sha256.
const DIR := "user://tests/playtest_bundle"
var cave
var failures := 0
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	failures += 1
	printerr("FAIL playtest bundle: ", message)
	quit(1)
func key(code: Key, pressed: bool, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed; event.ctrl_pressed = ctrl
	Input.parse_input_event(event)
func run() -> void:
	var feedback = root.get_node_or_null("PlaytestFeedback")
	if feedback == null: return fail("PlaytestFeedback autoload missing")
	var base := ProjectSettings.globalize_path(DIR)
	if DirAccess.dir_exists_absolute(base): OS.move_to_trash(base)
	feedback.output_root = DIR
	# Recording is off outside playtest/debug mode (R104 1): no per-frame work for ordinary players.
	if not feedback.recorder.recording_wanted():
		if feedback.recorder.recording or feedback.recorder.is_processing() or feedback.recorder.is_processing_input(): return fail("recorder runs outside playtest/debug mode")
	# This test is the playtest case.
	feedback.recorder.set_recording(true)
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(cave); current_scene = cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	if not cave.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var start: Vector3 = cave.player.global_position
	# Real input: walk forward, turn with the mouse, click once. Long enough for poses and at least one frame.
	key(KEY_W, true)
	for i in range(60):
		var look := InputEventMouseMotion.new(); look.relative = Vector2(3, 0); Input.parse_input_event(look)
		await process_frame
	for i in range(200): await process_frame
	key(KEY_W, false)
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; Input.parse_input_event(click)
	await process_frame
	click = click.duplicate(); click.pressed = false; Input.parse_input_event(click)
	var wait_until := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < wait_until: await process_frame
	if cave.player.global_position.distance_to(start) < 4.0: return fail("W did not move Luther (%s -> %s)" % [start, cave.player.global_position])
	key(KEY_F10, true); await process_frame; key(KEY_F10, false); await process_frame
	if not feedback.active: return fail("F10 did not open the report")
	feedback.note.text = "bundle test"
	key(KEY_ENTER, true, true); await process_frame; key(KEY_ENTER, false, true); await process_frame
	var path: String = feedback.last_saved
	if path.is_empty() or not FileAccess.file_exists(path.path_join("report.json")): return fail("No report written")
	var report = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("report.json")))
	if not report is Dictionary or report.get("bundle") != "bundle.json": return fail("report.json does not name the bundle")
	var bundle = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("bundle.json")))
	if not bundle is Dictionary: return fail("bundle.json unreadable")
	for file_name in bundle.files:
		if FileAccess.get_sha256(path.path_join(file_name)) != str(bundle.files[file_name]): return fail("sha256 mismatch for " + file_name)
	# The save of the moment validates as a whole-game document of the Cave and is not a player slot.
	if not bundle.files.has("save.json"): return fail("No save.json: %s" % [bundle.unavailable])
	var Save = load("res://scripts/lol2/game_save.gd")
	var doc: Dictionary = Save.read_document(path.path_join("save.json"))
	if not str(doc.error).is_empty(): return fail("save.json invalid: " + str(doc.error))
	if str(doc.state.area).is_empty() or doc.state.scene != cave.scene_file_path: return fail("save.json names %s / %s" % [doc.state.area, doc.state.scene])
	for id in range(1, 11):
		if FileAccess.file_exists(Save.slot_path(id)) and FileAccess.get_modified_time(Save.slot_path(id)) >= Time.get_unix_time_from_system() - 30:
			return fail("A player slot was written (%d)" % id)
	# Input history holds the real walk key, the click, mouse look and pose samples that moved.
	var inputs = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("inputs.json")))
	if not inputs is Dictionary: return fail("inputs.json unreadable")
	var kinds := {}
	var w_down := false
	for event in inputs.events:
		kinds[event.kind] = true
		if event.kind == "key" and event.key == "W" and event.pressed: w_down = true
	if not w_down or not kinds.has("mouse") or not kinds.has("look"): return fail("input history incomplete: %s w=%s" % [kinds.keys(), w_down])
	# The F10 press may be the last event (it marks the report moment); nothing typed afterwards may follow it.
	var f10_at := -1
	for i in inputs.events.size():
		var event: Dictionary = inputs.events[i]
		if event.kind == "key" and event.key == "F10" and event.pressed: f10_at = i
	if f10_at >= 0 and f10_at != inputs.events.size() - 1: return fail("input after F10 entered the history")
	if inputs.poses.size() < 4: return fail("too few pose samples: %d" % inputs.poses.size())
	var first: Dictionary = inputs.poses[0]
	var last: Dictionary = inputs.poses[inputs.poses.size() - 1]
	if Vector2(first.x, first.y).distance_to(Vector2(last.x, last.y)) < 4.0: return fail("poses do not show the walk")
	# Frames exist in a rendered run; log tail present or a stated reason.
	var frame_count := 0
	for file_name in bundle.files: if str(file_name).begins_with("frames/"): frame_count += 1
	if frame_count < 1: return fail("no frames: %s" % [bundle.unavailable])
	if not bundle.files.has("log_tail.txt") and not str(bundle.unavailable).contains("log_tail"): return fail("log tail neither written nor explained")
	if not bundle.has("first_error") or not bundle.build.has("commit"): return fail("bundle index lacks first_error/build")
	if not bundle.has("save_refused_by_game") or not bundle.has("save_omits"): return fail("bundle lacks the save refusal/omissions")
	# No home or absolute project path in the shared files (R104 4).
	var home := OS.get_environment("HOME")
	for file_name in ["bundle.json", "report.json", "log_tail.txt", "inputs.json"]:
		if FileAccess.file_exists(path.path_join(file_name)) and not home.is_empty() and FileAccess.get_file_as_string(path.path_join(file_name)).contains(home):
			return fail(file_name + " contains the home path")
	# The bundle loads (R104 3/6): move Luther away, load save.json, and he is back at the reported pose in a new Cave.
	var reported: Dictionary = inputs.poses[inputs.poses.size() - 1]
	cave.player.global_position += Vector3(80, 0, 80)
	var old_cave = cave
	var error: String = Save.load_file(self, path.path_join("save.json"))
	if not error.is_empty(): return fail("load_file refused: " + error)
	for i in range(900):
		await process_frame
		if current_scene != old_cave and is_instance_valid(current_scene) and current_scene.get("walkthrough_ready") == true: break
	if current_scene == old_cave or not is_instance_valid(current_scene) or current_scene.get("walkthrough_ready") != true: return fail("bundle load did not open a new Cave")
	cave = current_scene
	for i in range(10): await physics_frame
	var at: Vector3 = cave.player.global_position - cave.native_translation
	if Vector2(at.x, at.z).distance_to(Vector2(reported.x, reported.y)) > 6.0: return fail("loaded pose %s is not the reported pose %s" % [at, reported])
	print("PASS playtest bundle: F10 after real W/mouse/click writes save.json (valid Cave document, no player slot), inputs.json (%d events, %d poses), %d frames, log tail, sha256 index, no home paths, and save.json loads back to the reported pose" % [inputs.events.size(), inputs.poses.size(), frame_count])
	quit(0)
