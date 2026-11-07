extends SceneTree
## Earned Dark Halls detour save size (dark_halls_earned_detour_test --phase=depart, 2026-10-23). After the earned
## detour (Dark Halls population/windows/loot/doors/Rix state in the quests) and the departure to the darker jungle,
## F5 was refused: "Jungle save is too large." (old JungleSave guard 65536 bytes). The fixture is the exact state the
## darker-jungle quicksave would have written on that run (69,537 bytes). Checks: it validates; the save writer now
## writes it; it reads back unchanged; the darker jungle resumes it and saves it again.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Darker = preload("res://scripts/lol2/darker_jungle.gd")
const FIXTURE := "res://tests/fixtures/dark_halls_earned_darker_arrival_state.json"
const FIXTURE_SHA := "4eb2f646177253613bd1dc26ffe60627ff725e451dd15ba179c2869046c6b1ae"
const OLD_GUARD := 65536
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL dark_halls_detour_save_size: ", message); quit(1)
func run() -> void:
	if FileAccess.get_sha256(FIXTURE) != FIXTURE_SHA: return fail("Earned darker-arrival state fixture changed")
	var size := FileAccess.get_file_as_bytes(FIXTURE).size()
	if size <= OLD_GUARD: return fail("Fixture is not above the old guard")
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not state is Dictionary: return fail("Fixture is not JSON")
	var error := Save.validate(state, Darker.FORMAT)
	if not error.is_empty(): return fail("Earned darker-arrival state is invalid: " + error)
	if not bool(state.quests.get("dark_halls_windows", {}).get("done", false)) or not state.quests.has("dark_halls_population"): return fail("Fixture lacks the Dark Halls detour state")
	var path := "user://tests/dark_halls_detour_darker_size.json"
	error = Save.write_save(path, state, Darker.FORMAT)
	if not error.is_empty(): return fail("Save writer refused the earned darker-arrival state: " + error)
	var written := FileAccess.get_file_as_bytes(path).size()
	var reread := Save.read_save(path, Darker.FORMAT)
	if not str(reread.error).is_empty(): return fail("Read back: " + str(reread.error))
	# Whole-state text equality is not used: Godot's JSON float text is not bit-exact on a second round trip (one
	# hive_rune_population clock differs in the 17th digit); the carried quest keys and detour fields are compared.
	if reread.state.quests.keys() != state.quests.keys() or reread.state.inventory.collected != state.inventory.collected: return fail("Read back changed quest keys or items")
	for key in ["dark_halls_windows", "dark_halls_loot", "dark_halls_rix", "dark_halls_doors", "monastery"]:
		if reread.state.quests.get(key) != state.quests.get(key): return fail("Read back changed " + key)
	change_scene_to_file("res://scenes/lol2/darker_jungle.tscn")
	var darker: Node = null
	for i in 1500:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/lol2/darker_jungle.tscn" and current_scene.get("ready_for_review"): darker = current_scene; break
	if darker == null: return fail("Darker jungle not ready")
	error = darker.apply_save(reread.state)
	if not error.is_empty(): return fail("Resume: " + error)
	var again := "user://tests/dark_halls_detour_darker_size_again.json"
	error = darker.quicksave(again)
	if not error.is_empty(): return fail("Quicksave after resume: " + error)
	var resaved := Save.read_save(again, Darker.FORMAT)
	if not str(resaved.error).is_empty() or resaved.state.quests.dark_halls_windows != state.quests.dark_halls_windows or resaved.state.quests.monastery.globals.GV_LUTHERS_SOUL != state.quests.monastery.globals.GV_LUTHERS_SOUL or resaved.state.inventory.collected != state.inventory.collected: return fail("Resave lost the Dark Halls puzzle, soul or items")
	print("PASS dark_halls_detour_save_size: earned darker-arrival state (%d bytes, old guard %d) written (%d bytes), read back with quest keys and detour fields unchanged, resumed and saved again with puzzle/soul/items" % [size, OLD_GUARD, written])
	quit(0)
