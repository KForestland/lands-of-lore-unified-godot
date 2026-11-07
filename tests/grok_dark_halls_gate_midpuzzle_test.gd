extends SceneTree
## Private check for the patched r9 launch gate. A valid Dark Halls quicksave has
## six windows open and the orb reward not yet granted. Resume must load Dark Halls,
## consume lol2_dark_halls_resume, keep those six windows, and leave the soul unchanged.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const DarkHalls = preload("res://scripts/lol2/dark_halls.gd")
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
const OPENED := [237, 238, 239, 240, 241, 242]
const SOUL := 5
const POSITION := [-3043, 119, -2007]

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
	print("FAIL dark_halls_gate_midpuzzle: ", message)
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
	var quests: Dictionary = Quests.initial()
	quests.dark_halls_windows = {"opened": OPENED.duplicate(), "done": false}
	quests.monastery.globals.GV_LUTHERS_SOUL = SOUL
	var state := {
		"format": DarkHalls.FORMAT,
		"version": 1,
		"inventory": {"collected": [], "equipped_item": "", "equipped_armor": ""},
		"quests": quests,
		"player": {"position": POSITION.duplicate(), "yaw": 0.0, "pitch": 0.0},
	}
	var write_error := Save.write_save(DarkHalls.DEFAULT_PATH, state, DarkHalls.FORMAT)
	if not write_error.is_empty():
		return fail("Could not write mid-puzzle save: " + write_error)
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
	var scene = null
	for _i in 90:
		await process_frame
		scene = current_scene
		if scene != null and scene.scene_file_path == "res://scenes/lol2/dark_halls.tscn" and scene.get("ready_for_review") and scene.get("windows") != null:
			break
	if scene == null or scene.scene_file_path != "res://scenes/lol2/dark_halls.tscn":
		var where := "null"
		if scene != null:
			where = str(scene.scene_file_path)
		var status_text := ""
		if is_instance_valid(gate):
			var status: Label = gate.get("status")
			if status != null:
				status_text = status.text
		return fail("Resume did not load Dark Halls (%s) status=%s" % [where, status_text])
	if has_meta("lol2_dark_halls_resume"):
		return fail("lol2_dark_halls_resume was not consumed")
	var windows = scene.windows
	if windows == null or not is_instance_valid(windows):
		return fail("Window host missing after resume")
	var opened: Array = windows.opened()
	if opened != OPENED or windows.done():
		return fail("Windows restored as %s done=%s" % [opened, windows.done()])
	var soul := int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL)
	if soul != SOUL:
		return fail("Soul changed from %d to %d" % [SOUL, soul])
	if scene.exits_open():
		return fail("Exits opened on a 6/7 resume")
	var placed: Vector3 = scene.player.position
	if absf(placed.x - float(POSITION[0])) > 1.0 or absf(placed.z - float(POSITION[2])) > 1.0 or placed.y < 80.0 or placed.y > 160.0:
		return fail("Player at %s, expected entry arrival" % placed)
	var shades = scene.creatures
	if shades != null and is_instance_valid(shades) and shades.state.actors.has("58"):
		if int(shades.state.actors["58"].health) <= 0:
			return fail("Shade 58 is dead before the orb reward")
		shades.set_physics_process(false)
		shades.set_process(false)
	for _i in 30:
		await physics_frame
	if current_scene != scene:
		return fail("Idle frames left Dark Halls for %s" % current_scene.scene_file_path)
	if windows.done() or windows.opened() != OPENED or int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL) != SOUL or scene.exits_open():
		return fail("Puzzle advanced during idle frames: opened=%s done=%s soul=%s exits=%s" % [windows.opened(), windows.done(), scene.quest_state.monastery.globals.GV_LUTHERS_SOUL, scene.exits_open()])
	print("PASS dark_halls_gate_midpuzzle: Resume Dark Halls loaded windows %s done=false soul=%d exits shut meta consumed shade 58 alive" % [opened, soul])
	quit(0)
