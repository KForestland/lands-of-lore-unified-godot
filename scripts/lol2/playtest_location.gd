extends CanvasLayer
## Map X/Y use the horizontal Godot X/Z axes; H is height. Cave translation is removed.
var label: Label
var location := ""
var copied_until := 0
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and not location.is_empty():
		DisplayServer.clipboard_set(location)
		print("PLAYTEST LOCATION: ", location)
		copied_until = Time.get_ticks_msec() + 2000
		get_viewport().set_input_as_handled()
