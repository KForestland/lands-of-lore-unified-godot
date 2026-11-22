extends "res://tests/l13_elevator_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the basin save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_basin_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned basin -> physical elevator approach -> actual Spark -> saved original floor descent -> lower landing/reload"
