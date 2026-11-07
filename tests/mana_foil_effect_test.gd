extends SceneTree
const Effect=preload("res://scripts/lol2/mana_foil_effect.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mana_foil_native_adjustment.json"))
	for row in data.cases:
		if Effect.apply(int(row.current),int(row.maximum)) != (int(row.result)&0xffffffff):
			push_error("Mana foil native mismatch: "+str(row));quit(1);return
	print("PASS Mana foil50 native arithmetic fixtures including cap/zero/signed wrap")
	quit()
