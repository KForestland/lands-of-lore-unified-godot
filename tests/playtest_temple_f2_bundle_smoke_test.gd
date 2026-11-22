extends SceneTree
## r19a cut smoke (lead plan, owner Temple walk): through the gate's F2 list, the entry "Act 2 - Huline Temple, arrival
## (full health)" opens the Temple; real W walks Luther; F10 + comment + Ctrl+Enter writes a report whose bundle was
## recorded (the run passes --debug-mode, as the playtest launcher does), with inputs holding the W press and a
## save.json of the Temple. Needs LOL2_ORIGINAL_GAME_EXE and the staged F2 saves (tools/prepare_playtest_starts.py).
const GATE := "res://scenes/lol2/original_game_gate.tscn"
const ENTRY := "act2-l14"
const DIR := "user://tests/temple_f2_bundle"
var exe := OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	printerr("FAIL temple F2 bundle: ", message)
	quit(1)
func key(code: Key, pressed: bool, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed; event.ctrl_pressed = ctrl
	Input.parse_input_event(event)
func tap(code: Key, ctrl := false) -> void:
	key(code, true, ctrl); await process_frame; key(code, false, ctrl); await process_frame
func run() -> void:
	if exe.is_empty(): return fail("LOL2_ORIGINAL_GAME_EXE unset")
	var feedback = root.get_node_or_null("PlaytestFeedback")
	if feedback == null: return fail("PlaytestFeedback autoload missing")
	if not feedback.recorder.recording: return fail("recorder is off although --debug-mode is set")
	var base := ProjectSettings.globalize_path(DIR)
	if DirAccess.dir_exists_absolute(base): OS.move_to_trash(base)
	feedback.output_root = DIR
	var gate = load(GATE).instantiate()
	gate.settings_path = "user://tests/temple_f2_%d.cfg" % Time.get_ticks_usec()
	root.add_child(gate); current_scene = gate
	await process_frame
	gate.path_field.text = exe
	await tap(KEY_F2)
	if gate.starts_panel == null or not gate.starts_panel.visible: return fail("F2 did not open the start list")
	var row: Button = gate.starts_panel.find_child("Start_" + ENTRY, true, false)
	if row == null: return fail("no row " + ENTRY)
	if row.disabled: return fail("Temple row disabled (save not staged?)")
	var row_text := row.text
	if not "Huline Temple" in row_text: return fail("row text: " + row_text)
	row.pressed.emit()
	var scene: Node = null
	for i in 1200:
		await process_frame
		if current_scene != gate and is_instance_valid(current_scene) and current_scene.get("player") is Node3D:
			scene = current_scene
			break
	if scene == null: return fail("Temple did not open (status: %s)" % [gate.status.text if is_instance_valid(gate) else "freed"])
	if str(scene.get("area_id")) != "L14_HT": return fail("opened %s, not L14_HT" % [scene.get("area_id")])
	for i in 60: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var start: Vector3 = scene.player.global_position
	key(KEY_W, true)
	for i in 120: await physics_frame
	key(KEY_W, false)
	var wait_until := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < wait_until: await process_frame
	var moved: float = scene.player.global_position.distance_to(start)
	if moved < 4.0: return fail("W did not move Luther in the Temple (%.1f)" % moved)
	await tap(KEY_F10)
	if not feedback.active: return fail("F10 did not open the report")
	feedback.note.text = "r19a Temple smoke"
	await tap(KEY_ENTER, true)
	var path: String = feedback.last_saved
	if path.is_empty(): return fail("no report saved")
	var bundle = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("bundle.json")))
	if not bundle is Dictionary or not bundle.get("recording", false): return fail("bundle missing or recorded with recording off")
	if not bundle.files.has("save.json") or not bundle.files.has("inputs.json"): return fail("bundle files: %s / %s" % [bundle.files.keys(), bundle.unavailable])
	var doc: Dictionary = load("res://scripts/lol2/game_save.gd").read_document(path.path_join("save.json"))
	if not str(doc.error).is_empty() or str(doc.state.area) != "L14_HT": return fail("save.json: %s %s" % [doc.error, doc.get("state", {}).get("area", "")])
	var inputs = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("inputs.json")))
	var w := false
	for event in inputs.events: if event.kind == "key" and event.key == "W" and event.pressed: w = true
	if not w: return fail("inputs.json lacks the W press")
	print("PASS temple F2 bundle: F2 row '%s' opened L14_HT, real W moved Luther %.1f, F10 wrote a recorded bundle (save.json L14_HT, %d input events)" % [row_text, moved, inputs.events.size()])
	quit(0)
