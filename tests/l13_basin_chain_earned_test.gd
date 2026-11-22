extends "res://tests/l13_basin_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the egg-door save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_egg_door_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned first iris -> source eye/paired irises -> actual Spark vent -> saved modern drainage -> original145/146/147 physical pickups/reload"
