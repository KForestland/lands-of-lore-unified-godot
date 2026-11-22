extends RefCounted
## Local, immutable legacy packets; these helpers do not earn campaign progress.
static func document(area: String, slot: int = 4) -> Dictionary:
	var save = load("res://scripts/lol2/game_save.gd")
	var row: Dictionary = save.Areas.ROWS[area]
	return {"format":save.FORMAT,"version":save.CURRENT,"written_unix":1,"play_seconds":123.5,
		"label":row.label,"area":area,"scene":row.scene,
		"area_save":JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves_d5da60a/areas/"+area+".json")),
		"native_bank":{},"native_globals":preload("res://scripts/lol2/game_native_globals.gd").empty(),"session":{"options":{"adapter_exit_seeds":false},"last_slot":slot}}
