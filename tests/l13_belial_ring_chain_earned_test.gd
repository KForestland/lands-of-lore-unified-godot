extends "res://tests/l13_belial_ring_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the bridge save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_bridge_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned bridge -> physical upper ring -> original103 approach/save-reload; encounter admission not exercised"
