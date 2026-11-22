extends "res://tests/l13_egg_door_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the named L13 arrival save.
func input_path() -> String:
 return "res://tmp/l13_citadel_arrival_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned native citadel arrival -> original globe420 real Spark/mana -> original door106/region1226 opening -> physical crossing/save-reload"
