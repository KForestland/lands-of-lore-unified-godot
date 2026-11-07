extends RefCounted
## Hive Shalla placement. Control 75, static-assembly template 6. Cry groups stay unrun.
const SOURCE := "res://scripts/lol2/hive_shalla_source.json"
static func record() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var row: Dictionary = parsed
	return row
static func godot_position() -> Vector3:
	var native: Array = record().native
	return Vector3(float(native[0]), float(native[2]), -float(native[1]))
