extends "res://tests/area_owners/scene_snapshot.gd"
const Save = preload("res://scripts/lol2/act2_save.gd")
func kind() -> String: return "save"
func verify_scene(scene: Node, area: String) -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + area + "_save.json"))
	var error: String = scene.apply_save(legacy)
	check(error.is_empty(), area + " actual host applies immutable legacy save: " + error)
	var path := "user://area_owner_roundtrip.json"
	check(scene._quicksave_unrecorded(path).is_empty(), area + " actual save writer")
	var before: Dictionary = Save.read_save(path, scene.area_save_format).state
	scene.starting_magic.set_health(17)
	check(scene._quickload_unrecorded(path).is_empty(), area + " actual save loader / owner restore")
	check(scene.starting_magic.health() == int(before.inventory.health), area + " loaded player health")
	check(scene._quicksave_unrecorded(path).is_empty(), area + " actual second save")
	var after: Dictionary = Save.read_save(path, scene.area_save_format).state
	for field in ["inventory", "quests", "player", "format", "version"]:
		check(before[field] == after[field], area + " stable serialized " + field)
	check(scene.resets == 0, area + " no fall recovery during quiescent save contract")
	DirAccess.remove_absolute(path)
