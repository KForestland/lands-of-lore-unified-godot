extends SceneTree
const Shalla = preload("res://scripts/lol2/hive_shalla_state.gd")
func _initialize() -> void:
	var row: Dictionary = Shalla.record()
	assert(int(row.version) == 1 and int(row.control) == 75 and int(row.template) == 6)
	assert(str(row.name) == "Shalla")
	var native: Array = row.native
	assert(int(native[0]) == -1133 and int(native[1]) == 8885 and int(native[2]) == -235)
	assert(int(row.heading) == 7281 and (int(row.flags) & 4096) == 4096)
	var place: Vector3 = Shalla.godot_position()
	assert(int(place.x) == -1133 and int(place.y) == -235 and int(place.z) == -8885)
	var pack_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/native_scripts/L5_HC.json"))
	var pack: Dictionary = pack_parsed
	var hex := ""
	for item in pack.objects:
		var obj: Dictionary = item
		if str(obj.table) == "control" and int(obj.index) == 75:
			hex = str(obj.placement_hex)
	assert(hex == str(row.placement_hex) and hex.ends_with("06"))
	var dawn_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/hive_dawn20_population_source.json"))
	var dawn_pack: Dictionary = dawn_parsed
	var dawn: Dictionary = dawn_pack.actors[0]
	assert(int(dawn.actor) == 20 and int(dawn.definition) == 3 and str(dawn_pack.definitions["3"].name) == "Dawn")
	var dawn_pos: Array = dawn.position
	assert(int(dawn_pos[0]) == -3063 and int(dawn_pos[1]) == -1659 and int(dawn_pos[2]) == -6333)
	print("PASS: Shalla control 75 at (-1133, 8885) h-235; actor 20 stays Dawn")
	quit()
