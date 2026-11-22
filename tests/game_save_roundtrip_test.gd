extends "res://tests/legacy_save_fixture_test.gd"
const GameSave = preload("res://scripts/lol2/game_save.gd")
func verify_fresh_scene(scene: Node, area: String) -> bool:
	if area not in GameSave.Areas.PROGRESSION_AREAS: return true
	for i in 1500:
		if is_instance_valid(scene.get("act2_creatures")): break
		await process_frame
	assert(is_instance_valid(scene.get("act2_creatures")), area + " fresh population ready")
	# Observe the slot packet first: the old writer must not mask an omitted sync.
	var first: Dictionary = JSON.parse_string(JSON.stringify(scene.area_snapshot(), "", true, true))
	var path := "user://fresh_generic_legacy_packet.json"
	assert(scene._quicksave_unrecorded(path).is_empty(), area + " fresh legacy writer")
	assert(first == JSON.parse_string(FileAccess.get_file_as_string(path)), area + " snapshot before legacy writer is identical")
	DirAccess.remove_absolute(path)
	print("FRESH LEGACY PARITY ", area)
	return true

func verify_scene(scene: Node, area: String, legacy: Dictionary) -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE") == "1", "private profile driver required")
	var doc := GameSave.make_document(scene, 3)
	assert(GameSave.validate(doc).is_empty(), area)
	var path := GameSave.slot_path(3)
	assert(GameSave.write_document(path, doc).is_empty())
	var read := GameSave.read_document(path)
	assert(read.error.is_empty() and read.state.area_save == legacy, area + " inner packet is unchanged")
	assert(read.state.version == GameSave.CURRENT and read.state.scene == scene.scene_file_path)
	if area == "L8_SJ" and OS.get_environment("LOL2_CAPTURE_GAME_V1") == "1":
		assert(DirAccess.copy_absolute(path, "res://tests/fixtures/game_save_v1.json") == OK)
