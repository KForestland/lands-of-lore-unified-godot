extends CanvasLayer
var save_path := preload("res://scripts/lol2/museum_save.gd").DEFAULT_PATH
var walkthrough: Node
var status: Label
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color(0.02,0.015,0.01,0.92)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 360
	box.add_theme_constant_override("separation",18)
	center.add_child(box)
	var title := Label.new()
	title.text = "Time ran out"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",28)
	box.add_child(title)
	for entry in [["Retry exhibit",retry],["Load museum quicksave",load_quicksave]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 48
		button.pressed.connect(entry[1])
		box.add_child(button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
func retry() -> void:
	_restore(walkthrough.exhibit_retry.duplicate(true))
func load_quicksave() -> void:
	var result = walkthrough.Save.read_save(save_path)
	if not result.error.is_empty():
		status.text = result.error
		return
	_restore(result.state)
func _restore(state: Dictionary) -> void:
	var error: String = walkthrough.Save.validate(state)
	if not error.is_empty():
		status.text = error
		return
	get_tree().paused = false
	walkthrough.apply_save(state)
	queue_free()
