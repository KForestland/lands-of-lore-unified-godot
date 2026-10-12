extends RefCounted
const FORMAT := "lol2-restoration-hive"
const DEFAULT_PATH := "user://saves/hive_quicksave.json"
const Shared = preload("res://scripts/lol2/jungle_save.gd")
static func validate(state: Variant) -> String:
	return Shared.validate(state,FORMAT)
static func read_save(path: String = DEFAULT_PATH) -> Dictionary:
	var result := Shared.read_save(path,FORMAT)
	result.error = result.error.replace("jungle","Hive").replace("Jungle","Hive")
	return result
static func write_save(path: String, state: Dictionary) -> String:
	return Shared.write_save(path,state,FORMAT).replace("jungle","Hive").replace("Jungle","Hive")
