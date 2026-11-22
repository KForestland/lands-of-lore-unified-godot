extends "res://tests/l13_exit_lock_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the Dawn-release save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_dawn_release_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned Dawn stone ->physical elevator rise ->slot commit/retrieve ->native Claw Mountains exit/save-reload"
