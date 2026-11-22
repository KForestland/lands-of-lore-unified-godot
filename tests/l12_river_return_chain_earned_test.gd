extends "res://tests/l12_river_return_earned_test.gd"
## L12 return continuation. The parent still pins its qualified snapshot.
## This walk reads the armor save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l12_niche_armor_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS return chain: actual niche raft jump ->physical ride ->bank jump ->original ice bridge/save-reload"
