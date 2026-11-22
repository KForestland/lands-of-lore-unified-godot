extends "res://tests/l13_pink_steps_earned_test.gd"
## L13 continuation. The parent still pins its qualified snapshot.
## This walk reads the Dawn-recess save the previous step just wrote.
func input_path() -> String:
 return "res://tmp/l13_dawn_recess_earned_save.json"
func input_ready(path: String) -> bool:
 return FileAccess.file_exists(path)
func pass_line() -> String:
 return "PASS citadel chain: earned Dawn exit -> physical side ledge jumps beside original pink plates -> upper bridge approach -> actual save/reload"
