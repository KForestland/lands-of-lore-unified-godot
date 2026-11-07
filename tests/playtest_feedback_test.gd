extends SceneTree
const Feedback = preload("res://scripts/lol2/playtest_feedback.gd")
class InputOwner extends Node:
	var received := 0
	var ticks := 0
	func _process(_delta: float) -> void: ticks += 1
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_I: received += 1
class Host extends Node3D:
	var player: Node3D
	var native_translation := Vector3(100, 0, 200)
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
func run() -> void:
	var host := Host.new()
	host.name = "FeedbackTestArea"
	root.add_child(host)
	current_scene = host
	host.player = Node3D.new()
	host.add_child(host.player)
	host.player.position = Vector3(110, 30, 220)
	var camera := Camera3D.new()
	host.player.add_child(camera)
	camera.position = Vector3(4, 40, 0)
	camera.current = true
	var background := ColorRect.new()
	background.color = Color(0.2, 0.7, 0.3)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(background)
	var other := InputOwner.new()
	other.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(other)
	var feedback = root.get_node("PlaytestFeedback")
	await process_frame
	await RenderingServer.frame_post_draw
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	key(KEY_F10)
	await process_frame
	check(feedback.active and paused, "F10 must pause and open")
	var ticks_before: int = other.ticks
	for i in 5: await process_frame
	check(other.ticks == ticks_before, "ALWAYS overlay continues during report")
	check(not other.is_processing_input(), "other always-input owner still active")
	key(KEY_I)
	await process_frame
	check(other.received == 0, "typing leaked into other overlay")
	check(feedback.pending.position == {"x": 10.0, "y": 20.0, "h": 30.0, "rotation_radians": [0.0, 0.0, 0.0]}, "native position wrong")
	check(feedback.pending.native_translation == [100.0, 0.0, 200.0], "translation metadata missing")
	check(feedback.pending.camera.position == [114.0, 70.0, 220.0], "global camera position changed")
	check(feedback.pending.camera.native_position == {"x": 14.0, "y": 20.0, "h": 70.0}, "native camera position wrong")
	check(feedback.pending.render_camera.native_position == feedback.pending.camera.native_position, "render camera fallback wrong")
	check(not feedback.save_feedback() and feedback.active, "empty comment accepted")
	check(feedback.screenshot != null, "rendered capture unavailable")
	check(feedback.screenshot.get_pixel(640, 360).g > 0.6, "screenshot includes dialog or wrong frame")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture")
	root.get_texture().get_image().save_png("user://capture/feedback_panel.png")
	feedback.note.text = "The green floor should be lava. Æøå — test."
	feedback.output_root = "user://feedback_test_%s" % Time.get_ticks_usec()
	check(feedback.save_feedback(), "save failed")
	check(not paused and not feedback.active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "resume failed")
	check(other.process_mode == Node.PROCESS_MODE_ALWAYS, "overlay process mode not restored")
	check(other.is_processing_input(), "input owner not restored")
	var report = JSON.parse_string(FileAccess.get_file_as_string(feedback.last_saved.path_join("report.json")))
	check(report.description.contains("Æøå") and report.screenshot == "screenshot.png", "report roundtrip failed")
	check(FileAccess.file_exists(feedback.last_saved.path_join("screenshot.png")), "screenshot missing")
	check(not FileAccess.file_exists(feedback.last_saved.path_join("report.json.tmp")), "successful report not atomically finalized")
	check("X 10.0 Y 20.0 H 30.0" in DisplayServer.clipboard_get(), "shared report lacks readable coordinates")
	var first: String = feedback.last_saved
	paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	feedback.open_feedback()
	feedback.note.text = "Second report"
	check(feedback.save_feedback() and feedback.last_saved != first, "report overwrite")
	check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "preexisting pause lost")
	feedback.open_feedback()
	feedback.note.text = "Keep this on failure"
	feedback.output_root = first.path_join("report.json/no_directory")
	# This deliberately requests mkdir beneath a regular file. Silence only that expected engine I/O log;
	# verify the reporter returned its specific failure, retained the text, and stayed open.
	var print_errors := Engine.print_error_messages
	Engine.print_error_messages = false
	var saved: bool = feedback.save_feedback()
	Engine.print_error_messages = print_errors
	check(not saved and feedback.status.text.begins_with("Cannot create report folder") and feedback.note.text == "Keep this on failure" and feedback.active, "I/O failure discarded feedback")
	key(KEY_ESCAPE)
	await process_frame
	check(not feedback.active and paused, "cancel did not restore state")
	print("PASS: F10, screenshot before dialog, coordinates, comment validation, Unicode, repeated reports, pause/mouse restoration, I/O failure, Escape")
	quit(0)
