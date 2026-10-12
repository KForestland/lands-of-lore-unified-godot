extends CanvasLayer
## Map X/Y use the horizontal Godot X/Z axes; H is height. Cave translation is removed.
var label: Label
var location := ""
var copied_until := 0
## Development diagnostics panel (docs/dev-diagnostics.md): opt-in with the user argument --dev-diagnostics or
## LOL2_DEV_DIAGNOSTICS=1. F7 opens/closes it; the report is captured on open and on Refresh, never per frame, and
## is copied only by its Copy report button. Closing restores the previous pause and mouse state.
const Diagnostics = preload("res://scripts/lol2/dev_diagnostics.gd")
const PANEL_KEY := KEY_F7
var diagnostics_enabled := false
var panel: PanelContainer
var report_label: Label
var copy_button: Button
var refresh_button: Button
var report := {}
var report_text := ""
var prior_paused := false
var prior_mouse_mode := Input.MOUSE_MODE_VISIBLE
func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.position = Vector2(440, 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	diagnostics_enabled = "--dev-diagnostics" in OS.get_cmdline_user_args() or OS.get_environment("LOL2_DEV_DIAGNOSTICS") == "1"
func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null: label.hide(); return
	var player = scene.get("player")
	if not player is Node3D: label.hide(); return
	var at: Vector3 = player.position
	var translation = scene.get("native_translation")
	if translation is Vector3: at = player.global_position - translation
	var area := scene.scene_file_path.get_file().get_basename().replace("_walkthrough", "").replace("_review", "").replace("_", " ").capitalize()
	location = "%s | X %.1f  Y %.1f  H %.1f" % [area, at.x, at.z, at.y]
	label.text = location + (" | Copied" if Time.get_ticks_msec() < copied_until else " | F8 copy location")
	label.position = Vector2(maxf(16.0, (get_viewport().get_visible_rect().size.x - label.get_minimum_size().x) * 0.5), 8)
	label.show()
func _input(event: InputEvent) -> void:
	if diagnostics_enabled and event is InputEventKey and event.pressed and not event.echo and event.keycode == PANEL_KEY:
		if panel_open(): close_panel()
		else: open_panel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and not location.is_empty():
		DisplayServer.clipboard_set(location)
		print("PLAYTEST LOCATION: ", location)
		copied_until = Time.get_ticks_msec() + 2000
		get_viewport().set_input_as_handled()

func panel_open() -> bool: return panel != null and panel.visible
func open_panel() -> void:
	if not diagnostics_enabled or panel_open(): return
	if panel == null: _build_panel()
	prior_paused = get_tree().paused
	prior_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_report()
	panel.show()
func close_panel() -> void:
	if not panel_open(): return
	panel.hide()
	get_tree().paused = prior_paused
	Input.mouse_mode = prior_mouse_mode
func refresh_report() -> void:
	report = Diagnostics.capture(get_tree().current_scene)
	report_text = Diagnostics.format(report)
	if report_label != null: report_label.text = report_text
	if copy_button != null: copy_button.text = "Copy report"
func copy_report() -> void:
	DisplayServer.clipboard_set(report_text)
	print("DIAGNOSTICS REPORT COPIED (%d lines)" % report_text.count("\n"))
	copy_button.text = "Copied"
func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "DiagnosticsPanel"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24; panel.offset_top = 40; panel.offset_right = -24; panel.offset_bottom = -24
	# Opaque, so host review text underneath (e.g. the Hive geometry notes) cannot show through the report.
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.06, 0.08, 1.0)
	background.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", background)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for entry in [["Refresh", refresh_report], ["Copy report", copy_report], ["Close (F7)", close_panel]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons.add_child(button)
		if entry[0] == "Copy report": copy_button = button
		if entry[0] == "Refresh": refresh_button = button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	report_label = Label.new()
	report_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(report_label)
	panel.hide()
	add_child(panel)
