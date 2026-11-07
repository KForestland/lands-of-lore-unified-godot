extends SceneTree
## Private check for the frozen r9 launch gate. A Dark Halls quicksave file exists.
## The gate must offer "Resume Dark Halls" and, on an unreadable file, stay on the gate
## with a save error. It must not drop the player into the cave.
## Suite hygiene (Opus): the Dark Halls quicksave this test plants is removed again unless it existed before, so the
## gate's autostart in later tests is unchanged.
const _PLANTED := "user://saves/dark_halls_quicksave.json"
var _had_save := FileAccess.file_exists(_PLANTED)
func _finalize() -> void:
	if not _had_save and FileAccess.file_exists(_PLANTED): DirAccess.remove_absolute(_PLANTED)
func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL dark_halls_gate_resume: ", message)
	quit(1)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var save := FileAccess.open("user://saves/dark_halls_quicksave.json", FileAccess.WRITE)
	if save == null:
		return fail("Could not plant a Dark Halls quicksave")
	save.store_string("{}\n")
	save.close()
	change_scene_to_file("res://scenes/lol2/original_game_gate.tscn")
	for _i in 20:
		await process_frame
	var gate := current_scene
	if gate == null or gate.scene_file_path != "res://scenes/lol2/original_game_gate.tscn":
		return fail("Gate did not load")
	var button := find_button(gate, "Resume Dark Halls")
	if button == null:
		var labels: Array = []
		_labels(gate, labels)
		return fail("No Resume Dark Halls button. Buttons: %s" % [labels])
	var exe := OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
	if exe.is_empty():
		exe = "~/lol2_runtime_root/LOLG.EXE"
	gate.path_field.text = exe
	button.pressed.emit()
	for _i in 20:
		await process_frame
	if current_scene != gate:
		return fail("Unreadable Dark Halls save left the gate for %s" % current_scene.scene_file_path)
	var status: Label = gate.get("status")
	var text := status.text if status != null else ""
	if not text.contains("Unsupported area save"):
		return fail("Resume Dark Halls did not reject the planted save: %s" % text)
	if has_meta("lol2_dark_halls_resume"):
		return fail("Invalid save still set lol2_dark_halls_resume")
	print("PASS dark_halls_gate_resume: button present; invalid save stays on the gate (%s)" % text)
	quit(0)

func _labels(node: Node, labels: Array) -> void:
	if node is Button:
		labels.append(node.text)
	for child in node.get_children():
		_labels(child, labels)
