extends SceneTree
## Private check for the patched r9 launch gate. Finish the window puzzle, write the
## area quicksave, and resume through the gate. The soul must stay at the rewarded
## value and the grid shade must stay dead.
const DarkHalls = preload("res://scripts/lol2/dark_halls.gd")

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
	print("FAIL dark_halls_gate_done: ", message)
	quit(1)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func await_halls() -> Node:
	var scene = null
	for _i in 90:
		await process_frame
		scene = current_scene
		if scene != null and scene.scene_file_path == "res://scenes/lol2/dark_halls.tscn" and scene.get("ready_for_review") and scene.get("windows") != null:
			return scene
	return scene

func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	var scene = await await_halls()
	if scene == null or scene.scene_file_path != "res://scenes/lol2/dark_halls.tscn":
		return fail("Dark Halls did not load")
	var windows = scene.windows
	var shades = scene.creatures
	if windows == null or shades == null:
		return fail("Window or creature host missing")
	shades.set_physics_process(false)
	shades.set_process(false)
	var soul_before := int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL)
	var opened_ids: Array = []
	for index in 7:
		var control := int(windows.source.windows[index].control)
		opened_ids.append(control)
		if not windows.open_window(control):
			return fail("Could not open window %d" % control)
	if not windows.done() or windows.opened() != opened_ids:
		return fail("Puzzle did not finish at %s" % [windows.opened()])
	var soul_after := int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL)
	if soul_after != soul_before + 1:
		return fail("Soul %d -> %d, expected +1" % [soul_before, soul_after])
	if not shades.state.actors.has("58") or int(shades.state.actors["58"].health) != 0:
		return fail("Shade 58 survived the orb reward")
	var save_error: String = scene.quicksave(DarkHalls.DEFAULT_PATH)
	if not save_error.is_empty():
		return fail("Quicksave failed: " + save_error)
	change_scene_to_file("res://scenes/lol2/original_game_gate.tscn")
	for _i in 20:
		await process_frame
	var gate := current_scene
	if gate == null or gate.scene_file_path != "res://scenes/lol2/original_game_gate.tscn":
		return fail("Gate did not load")
	var button := find_button(gate, "Resume Dark Halls")
	if button == null:
		return fail("No Resume Dark Halls button")
	var exe := OS.get_environment("LOL2_ORIGINAL_GAME_EXE")
	if exe.is_empty():
		exe = "~/lol2_runtime_root/LOLG.EXE"
	gate.path_field.text = exe
	button.pressed.emit()
	var resumed = await await_halls()
	if resumed == null or resumed.scene_file_path != "res://scenes/lol2/dark_halls.tscn":
		return fail("Resume did not load Dark Halls")
	if has_meta("lol2_dark_halls_resume"):
		return fail("lol2_dark_halls_resume was not consumed")
	var resumed_windows = resumed.windows
	var resumed_shades = resumed.creatures
	if resumed_windows == null or resumed_shades == null:
		return fail("Window or creature host missing after resume")
	if not resumed_windows.done() or resumed_windows.opened() != opened_ids:
		return fail("Completed windows restored as %s done=%s" % [resumed_windows.opened(), resumed_windows.done()])
	var soul_resumed := int(resumed.quest_state.monastery.globals.GV_LUTHERS_SOUL)
	if soul_resumed != soul_after:
		return fail("Soul changed from %d to %d on resume" % [soul_after, soul_resumed])
	if not resumed.exits_open():
		return fail("Exits shut after a completed resume")
	if not resumed_shades.state.actors.has("58") or int(resumed_shades.state.actors["58"].health) != 0:
		return fail("Shade 58 revived on resume")
	resumed_shades.set_physics_process(false)
	resumed_shades.set_process(false)
	for _i in 30:
		await physics_frame
	if current_scene != resumed:
		return fail("Idle frames left Dark Halls for %s" % current_scene.scene_file_path)
	if int(resumed.quest_state.monastery.globals.GV_LUTHERS_SOUL) != soul_after or not resumed_windows.done():
		return fail("Puzzle rewarded again during idle frames")
	print("PASS dark_halls_gate_done: resume kept windows %s done=true soul=%d (no second grant) shade 58 dead exits open" % [opened_ids, soul_resumed])
	quit(0)
