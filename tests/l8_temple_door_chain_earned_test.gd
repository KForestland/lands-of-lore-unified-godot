extends "res://tests/l8_temple_door_earned_test.gd"
## L12 return continuation. The parent still pins its qualified snapshot.
## This walk reads the river-corridor save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l8_river_return_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS return chain: earned river corridor -> Temple approach -> Kit Dreamstone insert/save/retrieve -> original L14 arrival/save-reload"
