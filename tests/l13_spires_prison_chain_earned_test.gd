extends "res://tests/l13_spires_prison_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the cleared-Ruloi save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_ruloi_cleared_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: physical ground Spires/Spark -> Dawn jump/recess -> maidens jump/full original release -> earned save/reload"
