extends CanvasLayer
## Local owner feedback. No network, save writes or gameplay packer calls.
var saved_notice: Label
var notice_until := 0
var input_owners: Array = []
var process_owners: Array = []
var previous_focus: WeakRef
var panel: PanelContainer
var note: TextEdit
var status: Label
var prior_paused := false
var prior_mouse := Input.MOUSE_MODE_VISIBLE
var active := false
var pending := {}
var screenshot: Image
var last_saved := ""
var output_root := "user://playtest_feedback"

func _ready() -> void:
	var configured_root := OS.get_environment("LOL2_FEEDBACK_DIR")
	if configured_root.is_absolute_path(): output_root = configured_root
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	saved_notice = Label.new()
	saved_notice.position = Vector2(20, 42)
	saved_notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	saved_notice.add_theme_constant_override("shadow_offset_x", 2)
	saved_notice.add_theme_constant_override("shadow_offset_y", 2)
	add_child(saved_notice)
	saved_notice.hide()

func _process(_delta: float) -> void:
	if saved_notice.visible and Time.get_ticks_msec() >= notice_until: saved_notice.hide()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F10:
		get_viewport().set_input_as_handled()
		if not active: open_feedback()
	elif active and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_feedback()
	elif active and event.keycode == KEY_ENTER and event.ctrl_pressed:
		get_viewport().set_input_as_handled()
		save_feedback()

func open_feedback() -> void:
	if active: return
	active = true
	prior_paused = get_tree().paused
	prior_mouse = Input.mouse_mode
	get_tree().paused = true
	previous_focus = weakref(get_viewport().gui_get_focus_owner())
	input_owners.clear()
	process_owners.clear()
	_suspend_other_input(get_tree().root)
	# Read the last displayed game frame before showing any reporting UI.
	screenshot = null
	if DisplayServer.get_name() != "headless":
		screenshot = get_viewport().get_texture().get_image()
	pending = capture_context()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	note.text = ""
	status.text = "Screenshot captured. Describe what looks wrong." if screenshot != null and not screenshot.is_empty() else "Screenshot unavailable. Your location and comment can still be saved."
	saved_notice.hide()
	panel.get_parent().show()
	panel.show()
	note.grab_focus()

func _suspend_other_input(node: Node) -> void:
	if node == self: return
	if node.process_mode in [Node.PROCESS_MODE_ALWAYS, Node.PROCESS_MODE_WHEN_PAUSED]:
		process_owners.append({"node": weakref(node), "mode": node.process_mode})
		node.process_mode = Node.PROCESS_MODE_DISABLED
	var flags := [node.is_processing_input(), node.is_processing_shortcut_input(), node.is_processing_unhandled_input(), node.is_processing_unhandled_key_input()]
	if flags.has(true):
		input_owners.append({"node": weakref(node), "flags": flags})
		node.set_process_input(false)
		node.set_process_shortcut_input(false)
		node.set_process_unhandled_input(false)
		node.set_process_unhandled_key_input(false)
	for child in node.get_children(): _suspend_other_input(child)

func capture_context() -> Dictionary:
	var scene := get_tree().current_scene
	var result := {"schema": 1, "created_utc": Time.get_datetime_string_from_system(true),
		"build": ProjectSettings.get_setting("application/config/version", "unversioned"),
		"scene": scene.scene_file_path if scene != null else "", "scene_node": str(scene.name) if scene != null else "",
		"area": str(scene.name) if scene != null else "no scene",
		"coordinates": {"map": "X=Godot X, Y=Godot Z, H=Godot Y, with native_translation removed", "global": "Godot world X/Y/Z"},
		"position": {}, "camera": {}, "paused_before_report": prior_paused,
		"engine": Engine.get_version_info().string, "platform": OS.get_name()}
	if scene != null:
		var translation = scene.get("native_translation")
		if not translation is Vector3: translation = Vector3.ZERO
		result.native_translation = _vec(translation)
		var player = scene.get("player")
		if player is Node3D:
			var at: Vector3 = player.position
			at = player.global_position - translation
			result.position = {"x": at.x, "y": at.z, "h": at.y, "rotation_radians": _vec(player.global_rotation)}
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			result.camera = _camera_context(camera, translation)
			var drawn_camera = scene.get("index_camera")
			result.render_camera = _camera_context(drawn_camera if drawn_camera is Camera3D else camera, translation)
		if ResourceLoader.exists("res://scripts/lol2/dev_diagnostics.gd"):
			var diagnostics = load("res://scripts/lol2/dev_diagnostics.gd")
			result.diagnostics = diagnostics.capture(scene)
			if not str(result.diagnostics.area).is_empty(): result.area = result.diagnostics.area
	return result

func _camera_context(camera: Camera3D, translation: Vector3) -> Dictionary:
	var at := camera.global_position - translation
	return {"node": str(camera.get_path()), "position": _vec(camera.global_position),
		"position_space": "Godot global X/Y/Z", "native_position": {"x": at.x, "y": at.z, "h": at.y},
		"rotation_radians": _vec(camera.global_rotation), "fov": camera.fov}

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func close_feedback() -> void:
	if not active: return
	panel.hide()
	panel.get_parent().hide()
	active = false
	get_tree().paused = prior_paused
	Input.mouse_mode = prior_mouse
	for owner in input_owners:
		var node = owner.node.get_ref()
		if not is_instance_valid(node): continue
		node.set_process_input(owner.flags[0])
		node.set_process_shortcut_input(owner.flags[1])
		node.set_process_unhandled_input(owner.flags[2])
		node.set_process_unhandled_key_input(owner.flags[3])
	input_owners.clear()
	for owner in process_owners:
		var node = owner.node.get_ref()
		if is_instance_valid(node): node.process_mode = owner.mode
	process_owners.clear()
	var focus = previous_focus.get_ref() if previous_focus != null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()

func save_feedback() -> bool:
	if not active: return false
	if note.text.strip_edges().is_empty():
		status.text = "Please describe what looks wrong before saving."
		return false
	var base := ProjectSettings.globalize_path(output_root)
	var error := DirAccess.make_dir_recursive_absolute(base)
	if error != OK:
		status.text = "Cannot create report folder (%s). Your comment is still here." % error_string(error)
		return false
	var id := "report_%s_%s" % [Time.get_datetime_string_from_system(true).replace(":", "-"), str(Time.get_ticks_usec())]
	var path := base.path_join(id)
	error = DirAccess.make_dir_absolute(path)
	if error != OK:
		status.text = "Cannot create report (%s). Try again." % error_string(error)
		return false
	var record: Dictionary = pending.duplicate(true)
	record.description = note.text
	record.screenshot = ""
	record.screenshot_status = "unavailable"
	if screenshot != null and not screenshot.is_empty():
		error = screenshot.save_png(path.path_join("screenshot.png"))
		if error != OK:
			status.text = "Screenshot could not be saved (%s). Comment kept; try again." % error_string(error)
			return false
		record.screenshot = "screenshot.png"
		record.screenshot_status = "captured"
	# A completed report appears in the inbox only after its entire JSON has been written.
	var temporary := path.path_join("report.json.tmp")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		status.text = "Report could not be saved. Your comment is still here; try again."
		return false
	file.store_string(JSON.stringify(record, "\t") + "\n")
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		status.text = "Report write failed (%s). Your comment is still here." % error_string(error)
		return false
	error = DirAccess.rename_absolute(temporary, path.path_join("report.json"))
	if error != OK:
		status.text = "Report could not be finalized (%s). Your comment is still here." % error_string(error)
		return false
	last_saved = path
	var where := str(record.area)
	if not record.position.is_empty():
		where += " | X %.1f Y %.1f H %.1f" % [record.position.x, record.position.y, record.position.h]
	DisplayServer.clipboard_set("LoL2 feedback: " + path + "\n" + where + "\n" + note.text)
	print("PLAYTEST FEEDBACK SAVED: ", path)
	close_feedback()
	saved_notice.text = "Feedback saved. Report location copied — thank you!"
	notice_until = Time.get_ticks_msec() + 5000
	saved_notice.show()
	return true

func _build_panel() -> void:
	# Full-screen mouse blocker prevents clicks reaching inventory/story controls beneath the form.
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	blocker.hide()
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 100; panel.offset_top = 100; panel.offset_right = -100; panel.offset_bottom = -100
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.06, 0.08, 1)
	background.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", background)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "Report a problem — game paused"
	column.add_child(title)
	note = TextEdit.new()
	note.placeholder_text = "What looks wrong? What did you expect to happen?"
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(note)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var row := HBoxContainer.new()
	column.add_child(row)
	var save := Button.new()
	save.text = "Save report and resume (Ctrl+Enter)"
	save.pressed.connect(save_feedback)
	row.add_child(save)
	var cancel := Button.new()
	cancel.text = "Cancel (Esc)"
	cancel.pressed.connect(close_feedback)
	row.add_child(cancel)
	blocker.add_child(panel)
	panel.hide()
