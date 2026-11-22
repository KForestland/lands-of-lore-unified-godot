extends "res://tests/l13_lower_ruloi_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the upper-Ruloi save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_upper_ruloi_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned upper circuit -> actual second descent -> physical lower circuit and all nineteen Ruloi defeated/save-reload"
